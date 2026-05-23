kde-plasma-cleanup
A interactive Bash script for cleanly removing KDE Plasma and its associated configuration files from your system. Useful when switching desktop environments or doing a full Plasma reset.
Features

Interactive menu — choose to delete, backup, restore, or dry-run before committing to anything
Multi-distro support — works with pacman (Arch/CachyOS), apt (Debian/Ubuntu), and dnf (Fedora)
Full XDG cleanup — removes Plasma config, cache, and local data directories
Backup & restore — optionally back up your config before wiping, and restore it if needed
Dry-run mode — preview exactly what would be deleted without touching anything

Supported Distributions
Distro familyPackage managerArch, CachyOS, ManjaropacmanDebian, UbuntuaptFedoradnf
Usage
bash# Clone the repo
git clone https://github.com/BjornEinherji/kde-plasma-cleanup.git
cd kde-plasma-cleanup

# Make the script executable
chmod +x kde_plasma_cleanup.sh

# Run it
./kde_plasma_cleanup.sh
Follow the on-screen menu to choose your desired action.
⚠️ Disclaimer
Use this script at your own risk.
This script was developed with the assistance of AI tools. While it has been reviewed and tested, it may contain errors or behave unexpectedly on your specific system configuration. The author takes no responsibility for any data loss, system instability, broken configurations, or any other damage that may result from using this script.
Before running the script, it is strongly recommended to:

Read through the script so you understand what it does
Back up any important configuration files
Use the built-in dry-run mode first to preview changes

By using this script, you accept full responsibility for any outcomes.
License
This project is licensed under the GNU General Public License v3.0. See the LICENSE file for details.
