import json
import os
import fnmatch
import re

def generate_entries():
    rules_path = 'rules.json'
    if not os.path.exists(rules_path):
        print(f"Error: {rules_path} not found.")
        return

    with open(rules_path, 'r') as f:
        config = json.load(f)
    
    rules = config.get('rules', [])
    
    scan_dirs = {
        'payload/unix': 'UNIX_ISOS',
        'payload/windows': 'WIN_ISOS'
    }
    
    entries = []
    
    template = """menuentry "{menuentry}" {{
    search --no-floppy --set=root --label {label}
    probe -u $root --set=rootuuid
    set isofile="{iso_path_on_usb}"
    loopback loop $isofile
    linux (loop){kernel_path} {boot_params}
    initrd (loop){initrd_path}
}}"""

    for scan_dir, label in scan_dirs.items():
        if not os.path.isdir(scan_dir):
            continue
            
        for filename in sorted(os.listdir(scan_dir)):
            if filename.lower().endswith('.iso'):
                if not re.match(r'^[A-Za-z0-9_.-]+$', filename):
                    print(f"Warning: ISO filename '{filename}' contains unsafe characters. Skipping.")
                    continue
                
                matched_rule = None
                for rule in rules:
                    if fnmatch.fnmatch(filename, rule['match']):
                        matched_rule = rule
                        break
                
                if matched_rule:
                    iso_path_on_usb = f"/{filename}"
                    boot_params = matched_rule['boot_params'].replace('${iso_path}', '$isofile').replace('${root_uuid}', '$rootuuid')
                    
                    entry = template.format(
                        menuentry=matched_rule['menuentry'],
                        label=label,
                        iso_path_on_usb=iso_path_on_usb,
                        kernel_path=matched_rule['kernel_path'],
                        boot_params=boot_params,
                        initrd_path=matched_rule['initrd_path']
                    )
                    entries.append(entry)
                else:
                    print(f"No rule matched for {filename}")

    with open('entries.cfg', 'w') as f:
        if entries:
            f.write('\n\n'.join(entries) + '\n')
        else:
            f.write('# No ISO files found matching any rules.\n')

if __name__ == '__main__':
    for d in ['payload/unix', 'payload/windows']:
        os.makedirs(d, exist_ok=True)
    generate_entries()
