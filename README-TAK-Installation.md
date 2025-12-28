# TAK Server Installation Script for Rocky Linux 9.7

This script automates the installation of TAK Server on a Rocky Linux 9.7 virtual machine.

## Prerequisites

- Rocky Linux 9.7 installed and running
- Root or sudo access
- Internet connection for downloading packages
- At least 4GB RAM and 20GB disk space recommended

## Usage

### 1. Transfer the Script to Your VM

You can transfer the script to your Rocky Linux 9.7 VM using one of these methods:

**Option A: Using SCP (from your local machine)**
```bash
scp install-tak-server-rocky9.sh user@vm-ip-address:/tmp/
```

**Option B: Copy and paste the script content**
- Copy the script content
- On the VM, create the file: `nano /tmp/install-tak-server-rocky9.sh`
- Paste the content and save

**Option C: Download directly on the VM**
```bash
# If you have the script in a repository or accessible URL
wget <script-url> -O /tmp/install-tak-server-rocky9.sh
```

### 2. Make the Script Executable

```bash
chmod +x /tmp/install-tak-server-rocky9.sh
```

### 3. Run the Installation Script

```bash
sudo /tmp/install-tak-server-rocky9.sh
```

Or if you're already root:
```bash
/tmp/install-tak-server-rocky9.sh
```

## What the Script Does

The installation script performs the following steps:

1. **System Update**: Updates all system packages to the latest versions
2. **Install Dependencies**: Installs required packages (wget, curl, git, Java, etc.)
3. **Install Java**: Installs OpenJDK 17 (required for TAK Server)
4. **Install TAK Server**: 
   - Option 1: Uses the `installTAK` script (recommended)
   - Option 2: Manual installation with provided package URL
5. **Configure SELinux**: Applies TAK Server SELinux policies if SELinux is enforcing
6. **Configure Firewall**: Opens necessary ports (8089, 8443, 8444, 8088)
7. **Set Permissions**: Configures proper file ownership for TAK Server
8. **Service Setup**: Enables and optionally starts the TAK Server service

## Installation Options

During installation, you'll be prompted to choose:

1. **Installation Method**:
   - **Option 1 (Recommended)**: Uses the `installTAK` script which automates the entire process
   - **Option 2**: Manual installation if you have a specific TAK Server package URL

2. **Service Start**: Choose whether to start TAK Server immediately after installation

## Post-Installation

After installation completes:

1. **Access the Web UI**: Navigate to `https://<your-vm-ip>:8444` in a web browser
2. **Configure Certificates**: Set up SSL/TLS certificates for secure communication
3. **Review Configuration**: Check and modify settings in `/opt/tak/CoreConfig.xml` if needed
4. **Check Service Status**: 
   ```bash
   sudo systemctl status takserver
   ```

## Useful Commands

```bash
# Start TAK Server
sudo systemctl start takserver

# Stop TAK Server
sudo systemctl stop takserver

# Restart TAK Server
sudo systemctl restart takserver

# Check Status
sudo systemctl status takserver

# View Logs
sudo journalctl -u takserver -f

# If using manual startup script
/opt/tak/takserver.sh start
/opt/tak/takserver.sh stop
/opt/tak/takserver.sh status
```

## Troubleshooting

### Java Issues
If Java is not found after installation:
```bash
# Verify Java installation
java -version

# Set JAVA_HOME if needed
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
```

### SELinux Issues
If SELinux is blocking TAK Server:
```bash
cd /opt/tak
sudo ./apply-selinux.sh
```

### Firewall Issues
If you can't access TAK Server from outside:
```bash
# Check firewall status
sudo firewall-cmd --list-all

# Manually add ports if needed
sudo firewall-cmd --permanent --add-port=8444/tcp
sudo firewall-cmd --reload
```

### Service Won't Start
Check the logs:
```bash
sudo journalctl -u takserver -n 50
```

## Additional Resources

- TAK Server Certificate Enrollment: https://github.com/misterdallas/TAK-Server-Certificate-Enrollment
- installTAK Script: https://github.com/myTeckNet/installTAK
- Official TAK Server Documentation: Check the TAK Server official documentation

## Notes

- The script is designed to be idempotent where possible, but re-running may require user confirmation
- Always backup your configuration before making changes
- Ensure your VM has sufficient resources (CPU, RAM, disk space)
- Network connectivity is required for package downloads

## Support

For issues specific to:
- **This installation script**: Review the script output and error messages
- **TAK Server**: Consult TAK Server official documentation
- **Rocky Linux**: Check Rocky Linux documentation and forums

