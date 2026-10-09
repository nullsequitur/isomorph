# IsoMorph
> Morphing ISOs into a seamless boot environment

A robust, automated tool for creating a multiboot USB drive with GRUB. 
This project uses a combination of a native Bash installer for disk management and Python 3 for dynamic configuration generation.

## Features (V1)
- **Universal Booting**: Supports both UEFI and BIOS legacy systems.
- **Dynamic Entries**: Automatically generates GRUB boot menus based on detected ISOs and parsing rules.
- **Modular Config**: Split GRUB configuration (`grub.cfg`, `entries.cfg`, `functions.cfg`) for easy manual tweaking on the go.
- **Custom Fonts & Themes**: Minimalist aesthetic with support for standard themes and adjustable font sizes.

*(Note: Automated Secure Boot setup is not included in V1. You will need to temporarily disable Secure Boot on the target machine to boot this USB).*

## Project History
This repository is a ground-up refactor of my original functional multiboot USB project. The legacy version featured custom theme selection, various graphical easter eggs, and hardwired configurations. I originally presented it to my students in the "New Technologies" class at the University of Ioannina (UoI) — the same academic setting that produced the collaborative open-source physics textbook. 

While the initial version was highly effective for educational demonstration, its monolithic scripts were difficult to scale and maintain. This modern V1 rewrite was undertaken with the assistance of the Antigravity CLI to establish a modular, scalable, and professional architecture, starting minimal and building up functionality over time.
