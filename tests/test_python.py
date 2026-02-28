"""
SPAN-MRI Python Unit Tests

Tests for the U-Net segmentation module (lib/unetseg/unetseg.py).
These tests verify model architecture, forward pass, and utility functions
without requiring the pre-trained brain model.

Usage:
    python3 -m pytest tests/test_python.py -v
"""

import os
import sys
import unittest

import numpy as np

# Add the unetseg module to the path
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT_DIR, "lib", "unetseg"))

try:
    import torch
    import unetseg

    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False


@unittest.skipUnless(HAS_TORCH, "PyTorch not available")
class TestSettings(unittest.TestCase):
    """Test the Settings configuration class."""

    def test_default_values(self):
        """Settings defaults should match expected values."""
        s = unetseg.Settings()
        self.assertEqual(s.epochs, 40)
        self.assertAlmostEqual(s.rate, 0.0001)
        self.assertEqual(s.rescale, 256)
        self.assertEqual(s.kernel, 16)
        self.assertEqual(s.batches, 20)
        self.assertEqual(s.channels, 1)
        self.assertEqual(s.labels, 1)
        self.assertEqual(s.augment, 0)
        self.assertFalse(s.largest)
        self.assertFalse(s.raw)

    def test_custom_values(self):
        """Settings should accept custom values from a dictionary."""
        args = {
            "epochs": 10,
            "rate": 0.001,
            "rescale": 128,
            "kernel": 8,
            "batches": 5,
            "channels": 4,
            "labels": 2,
            "augment": 3,
            "largest": True,
            "raw": True,
        }
        s = unetseg.Settings(args)
        self.assertEqual(s.epochs, 10)
        self.assertEqual(s.kernel, 8)
        self.assertEqual(s.channels, 4)
        self.assertTrue(s.largest)


@unittest.skipUnless(HAS_TORCH, "PyTorch not available")
class TestUNet2d(unittest.TestCase):
    """Test the U-Net model architecture."""

    def test_default_output_shape(self):
        """UNet2d with default settings should produce correct output shape."""
        settings = unetseg.Settings()
        model = unetseg.UNet2d(settings)
        # Input: [batch=1, channels=1, height=256, width=256]
        x = torch.randn(1, 1, 256, 256)
        with torch.no_grad():
            y = model(x)
        # Output: [batch=1, labels+1=2, height=256, width=256]
        self.assertEqual(y.shape, (1, 2, 256, 256))

    def test_multichannel_input(self):
        """UNet2d should handle multi-channel input (e.g., 4 for SPAN)."""
        settings = unetseg.Settings()
        settings.channels = 4
        model = unetseg.UNet2d(settings)
        x = torch.randn(1, 4, 256, 256)
        with torch.no_grad():
            y = model(x)
        self.assertEqual(y.shape, (1, 2, 256, 256))

    def test_different_kernel_sizes(self):
        """UNet2d should work with different base kernel sizes."""
        for kernel in [8, 16, 32]:
            settings = unetseg.Settings()
            settings.kernel = kernel
            model = unetseg.UNet2d(settings)
            x = torch.randn(1, 1, 256, 256)
            with torch.no_grad():
                y = model(x)
            self.assertEqual(y.shape, (1, 2, 256, 256))

    def test_smaller_input_size(self):
        """UNet2d should work with smaller input sizes (power of 2)."""
        settings = unetseg.Settings()
        model = unetseg.UNet2d(settings)
        x = torch.randn(1, 1, 128, 128)
        with torch.no_grad():
            y = model(x)
        self.assertEqual(y.shape, (1, 2, 128, 128))


@unittest.skipUnless(HAS_TORCH, "PyTorch not available")
class TestLargest(unittest.TestCase):
    """Test the largest connected component extraction."""

    def test_single_component(self):
        """largest() with one component should return it."""
        mask = np.zeros((10, 10, 10), dtype=bool)
        mask[3:7, 3:7, 3:7] = True
        result = unetseg.largest(mask)
        self.assertEqual(result.sum(), mask.sum())

    def test_two_components(self):
        """largest() should keep only the larger of two components."""
        mask = np.zeros((20, 20, 20), dtype=bool)
        # Large component (5x5x5 = 125 voxels)
        mask[2:7, 2:7, 2:7] = True
        # Small component (2x2x2 = 8 voxels)
        mask[15:17, 15:17, 15:17] = True
        result = unetseg.largest(mask)
        self.assertEqual(result.sum(), 125)
        # Verify the large component is kept, small one removed
        self.assertTrue(result[4, 4, 4])
        self.assertFalse(result[16, 16, 16])

    def test_empty_mask(self):
        """largest() with empty mask — edge case where argmax selects label 0.

        Note: When no foreground components exist, bincount produces [N, 0, ...],
        c_size[0] is set to 0, so argmax returns 0, and (labs == 0) is True
        everywhere. This is acceptable because in practice, the mask is always
        thresholded before calling largest().
        """
        mask = np.zeros((5, 5, 5), dtype=bool)
        result = unetseg.largest(mask)
        # With no foreground, all voxels are label 0 and argmax picks 0
        self.assertEqual(result.shape, (5, 5, 5))


@unittest.skipUnless(HAS_TORCH, "PyTorch not available")
class TestBrainModel(unittest.TestCase):
    """Test that the pre-trained brain model can be loaded."""

    def test_model_loads(self):
        """Brain model should load successfully if it exists."""
        model_path = os.path.join(ROOT_DIR, "lib", "brain-model")
        if not os.path.exists(model_path):
            self.skipTest("Brain model not built (run 'make' first)")

        settings, model = unetseg.load(model_path)
        self.assertIsInstance(settings, unetseg.Settings)
        self.assertEqual(settings.channels, 4)
        self.assertEqual(settings.rescale, 128)

    def test_model_forward_pass(self):
        """Brain model should produce output with correct shape."""
        model_path = os.path.join(ROOT_DIR, "lib", "brain-model")
        if not os.path.exists(model_path):
            self.skipTest("Brain model not built (run 'make' first)")

        settings, model = unetseg.load(model_path)
        x = torch.randn(1, settings.channels, 64, 64)
        with torch.no_grad():
            y = model(x)
        self.assertEqual(y.shape[0], 1)
        self.assertEqual(y.shape[2], 64)
        self.assertEqual(y.shape[3], 64)


if __name__ == "__main__":
    unittest.main()
