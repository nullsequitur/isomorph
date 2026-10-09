import unittest
import os
import tempfile
import shutil
import json
import sys
from io import StringIO
from unittest.mock import patch

# Add the project directory to sys.path so we can import generate_menu
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
from generate_menu import generate_entries


class TestGenerateMenu(unittest.TestCase):
    def setUp(self):
        # Create a temporary directory and change the current working directory
        self.test_dir = tempfile.mkdtemp()
        self.original_cwd = os.getcwd()
        os.chdir(self.test_dir)
        
        # Setup basic directory structure
        os.makedirs('payload/unix')
        os.makedirs('payload/windows')

    def tearDown(self):
        # Restore original cwd and remove temp directory
        os.chdir(self.original_cwd)
        shutil.rmtree(self.test_dir)

    def test_generate_entries_success(self):
        # Create rules.json
        rules_data = {
            "rules": [
                {
                    "match": "ubuntu*.iso",
                    "menuentry": "Ubuntu",
                    "kernel_path": "/casper/vmlinuz",
                    "initrd_path": "/casper/initrd",
                    "boot_params": "boot=casper iso-scan/filename=${iso_path} quiet splash ---"
                }
            ]
        }
        with open('rules.json', 'w') as f:
            json.dump(rules_data, f)
            
        # Create dummy ISOs
        open('payload/unix/ubuntu-22.04-desktop-amd64.iso', 'w').close()
        open('payload/unix/not-an-iso.txt', 'w').close() # Should be ignored
        
        generate_entries()
        
        self.assertTrue(os.path.exists('entries.cfg'))
        with open('entries.cfg', 'r') as f:
            content = f.read()
            
        expected_template = """menuentry "Ubuntu" {
    set isofile="/payload/unix/ubuntu-22.04-desktop-amd64.iso"
    loopback loop $isofile
    linux (loop)/casper/vmlinuz boot=casper iso-scan/filename=$isofile quiet splash ---
    initrd (loop)/casper/initrd
}
"""
        self.assertEqual(content, expected_template)

    @patch('sys.stdout', new_callable=StringIO)
    def test_generate_entries_no_matching_rule(self, mock_stdout):
        # Create rules.json
        rules_data = {
            "rules": [
                {
                    "match": "ubuntu*.iso",
                    "menuentry": "Ubuntu",
                    "kernel_path": "/casper/vmlinuz",
                    "initrd_path": "/casper/initrd",
                    "boot_params": "boot=casper"
                }
            ]
        }
        with open('rules.json', 'w') as f:
            json.dump(rules_data, f)
            
        # Create a dummy ISO that doesn't match
        open('payload/unix/fedora.iso', 'w').close()
        
        generate_entries()
        
        self.assertTrue(os.path.exists('entries.cfg'))
        with open('entries.cfg', 'r') as f:
            content = f.read()
            
        self.assertEqual(content, "# No ISO files found matching any rules.\n")
        self.assertIn("No rule matched for fedora.iso", mock_stdout.getvalue())

    @patch('sys.stdout', new_callable=StringIO)
    def test_generate_entries_missing_rules_json(self, mock_stdout):
        # Do NOT create rules.json
        # Call generate_entries
        generate_entries()
        
        # Verify error message is printed
        self.assertIn("Error: rules.json not found.", mock_stdout.getvalue())
        # entries.cfg should not be created
        self.assertFalse(os.path.exists('entries.cfg'))

if __name__ == '__main__':
    unittest.main()
