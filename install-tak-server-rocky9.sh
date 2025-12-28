#!/bin/bash

###############################################################################
# TAK Server Installation Script for Rocky Linux 9.7
# This script automates the installation of TAK Server on Rocky Linux 9.7
###############################################################################

set -e  # Exit on any error

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (use sudo)"
    exit 1
fi

log "Starting TAK Server installation for Rocky Linux 9.7"

###############################################################################
# Step 1: System Update
###############################################################################
log "Step 1: Updating system packages..."
dnf update -y

###############################################################################
# Step 2: Install Required Dependencies
###############################################################################
log "Step 2: Installing required dependencies..."

# Install EPEL repository if not already installed
if ! rpm -q epel-release > /dev/null 2>&1; then
    log "Installing EPEL repository..."
    dnf install -y epel-release
fi

# Install base dependencies
log "Installing base packages..."
dnf install -y \
    wget \
    curl \
    git \
    unzip \
    tar \
    net-tools \
    firewalld \
    policycoreutils-python-utils \
    which

###############################################################################
# Step 3: Install Java (OpenJDK 17 - recommended for TAK Server)
###############################################################################
log "Step 3: Installing Java (OpenJDK 17)..."

# Check if Java is already installed
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    warning "Java is already installed: $JAVA_VERSION"
    read -p "Do you want to continue with existing Java installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installing OpenJDK 17..."
        dnf install -y java-17-openjdk java-17-openjdk-devel
    fi
else
    log "Installing OpenJDK 17..."
    dnf install -y java-17-openjdk java-17-openjdk-devel
fi

# Set JAVA_HOME
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
export JAVA_HOME

# Verify Java installation
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    log "Java installation verified: $JAVA_VERSION"
else
    error "Java installation failed!"
    exit 1
fi

###############################################################################
# Step 4: Download and Install TAK Server
###############################################################################
log "Step 4: Downloading and installing TAK Server..."

TAK_DIR="/opt/tak"
TAK_USER="tak"
TAK_GROUP="tak"

# Create tak user and group if they don't exist
if ! id "$TAK_USER" &>/dev/null; then
    log "Creating TAK user and group..."
    groupadd -r $TAK_GROUP
    useradd -r -g $TAK_GROUP -d $TAK_DIR -s /bin/false $TAK_USER
fi

# Create TAK directory
mkdir -p $TAK_DIR
cd $TAK_DIR

# Check if TAK Server is already installed
if [ -f "$TAK_DIR/takserver.sh" ]; then
    warning "TAK Server appears to be already installed in $TAK_DIR"
    read -p "Do you want to reinstall? This may overwrite existing configuration. (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled by user."
        exit 0
    fi
fi

# Prompt for TAK Server package URL or use installTAK script
log "TAK Server installation options:"
echo "1. Use installTAK script (recommended - automated)"
echo "2. Manual installation (requires TAK Server RPM/package URL)"
read -p "Select installation method (1 or 2): " INSTALL_METHOD

if [ "$INSTALL_METHOD" == "1" ]; then
    # Method 1: Use installTAK script
    log "Using installTAK script method..."
    INSTALLTAK_DIR="/tmp/installTAK"
    
    if [ -d "$INSTALLTAK_DIR" ]; then
        log "Removing existing installTAK directory..."
        rm -rf $INSTALLTAK_DIR
    fi
    
    log "Cloning installTAK repository..."
    cd /tmp
    git clone https://github.com/myTeckNet/installTAK.git
    cd installTAK
    
    log "Making installTAK script executable..."
    chmod +x installTAK
    
    log "Running installTAK script..."
    ./installTAK
    
    log "installTAK script completed."
    
elif [ "$INSTALL_METHOD" == "2" ]; then
    # Method 2: Manual installation
    read -p "Enter TAK Server package URL (or press Enter to skip): " TAK_PACKAGE_URL
    
    if [ -n "$TAK_PACKAGE_URL" ]; then
        log "Downloading TAK Server package from: $TAK_PACKAGE_URL"
        wget -O takserver.rpm "$TAK_PACKAGE_URL"
        
        log "Installing TAK Server package..."
        dnf install -y ./takserver.rpm
        
        log "TAK Server package installed."
    else
        warning "No package URL provided. Skipping manual installation."
        log "You can manually download and install TAK Server later."
    fi
else
    error "Invalid selection. Exiting."
    exit 1
fi

###############################################################################
# Step 5: Configure SELinux
###############################################################################
log "Step 5: Configuring SELinux..."

# Check SELinux status
SELINUX_STATUS=$(getenforce)
log "Current SELinux status: $SELINUX_STATUS"

if [ "$SELINUX_STATUS" == "Enforcing" ]; then
    if [ -f "$TAK_DIR/apply-selinux.sh" ]; then
        log "Applying TAK Server SELinux policies..."
        cd $TAK_DIR
        chmod +x apply-selinux.sh
        ./apply-selinux.sh
        log "SELinux policies applied."
    else
        warning "SELinux is enforcing but apply-selinux.sh not found in $TAK_DIR"
        warning "You may need to manually configure SELinux policies later."
    fi
else
    log "SELinux is not enforcing. No additional configuration needed."
fi

###############################################################################
# Step 6: Configure Firewall
###############################################################################
log "Step 6: Configuring firewall..."

# Check if firewalld is running
if systemctl is-active --quiet firewalld; then
    log "Firewalld is active. Configuring firewall rules..."
    
    # TAK Server default ports
    # 8089 - HTTP API
    # 8443 - HTTPS API
    # 8444 - Web UI
    # 8088 - Web UI HTTP (if needed)
    # 8080 - Core messaging (if needed)
    
    log "Opening TAK Server ports..."
    firewall-cmd --permanent --add-port=8089/tcp
    firewall-cmd --permanent --add-port=8443/tcp
    firewall-cmd --permanent --add-port=8444/tcp
    firewall-cmd --permanent --add-port=8088/tcp
    
    # Reload firewall
    firewall-cmd --reload
    log "Firewall rules configured."
else
    warning "Firewalld is not running. Skipping firewall configuration."
    warning "You may need to manually configure firewall rules later."
fi

###############################################################################
# Step 7: Set Permissions
###############################################################################
log "Step 7: Setting file permissions..."

if [ -d "$TAK_DIR" ]; then
    chown -R $TAK_USER:$TAK_GROUP $TAK_DIR
    log "Permissions set for $TAK_DIR"
fi

###############################################################################
# Step 8: Enable and Start TAK Server Service
###############################################################################
log "Step 8: Configuring TAK Server service..."

# Check for systemd service
if [ -f "/etc/systemd/system/takserver.service" ] || [ -f "/usr/lib/systemd/system/takserver.service" ]; then
    log "TAK Server systemd service found."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable service
    systemctl enable takserver
    
    log "TAK Server service enabled."
    log "To start the service, run: systemctl start takserver"
    
    read -p "Do you want to start TAK Server service now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl start takserver
        
        # Wait a moment for service to start
        sleep 3
        
        # Check service status
        if systemctl is-active --quiet takserver; then
            log "TAK Server service started successfully!"
        else
            error "TAK Server service failed to start. Check logs with: journalctl -u takserver"
        fi
    fi
else
    warning "TAK Server systemd service not found."
    warning "You may need to manually configure the service or use the TAK Server startup script."
    
    if [ -f "$TAK_DIR/takserver.sh" ]; then
        log "TAK Server startup script found at $TAK_DIR/takserver.sh"
        log "You can start TAK Server manually with: $TAK_DIR/takserver.sh start"
    fi
fi

###############################################################################
# Step 9: Post-Installation Information
###############################################################################
log "Step 9: Installation summary..."

echo ""
echo "================================================================================"
echo "TAK Server Installation Complete!"
echo "================================================================================"
echo ""
echo "Installation Directory: $TAK_DIR"
echo "TAK User: $TAK_USER"
echo "Java Version: $(java -version 2>&1 | head -n 1)"
echo ""
echo "Next Steps:"
echo "1. Configure TAK Server certificates (if not done during installation)"
echo "2. Access TAK Server web UI (typically at https://<server-ip>:8444)"
echo "3. Configure TAK Server settings in $TAK_DIR/CoreConfig.xml"
echo "4. Review firewall rules and adjust as needed"
echo ""
echo "Useful Commands:"
echo "  - Start TAK Server: systemctl start takserver"
echo "  - Stop TAK Server: systemctl stop takserver"
echo "  - Check Status: systemctl status takserver"
echo "  - View Logs: journalctl -u takserver -f"
echo ""
if [ -f "$TAK_DIR/takserver.sh" ]; then
    echo "  - Manual Start: $TAK_DIR/takserver.sh start"
    echo "  - Manual Stop: $TAK_DIR/takserver.sh stop"
fi
echo ""
echo "For certificate enrollment setup, see:"
echo "https://github.com/misterdallas/TAK-Server-Certificate-Enrollment"
echo ""
echo "================================================================================"
echo ""

log "Installation script completed successfully!"

