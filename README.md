# **🤖 OpenClaw Android (Termux \+ Shizuku AI Agent)**

An automated non-interactive installer to run **OpenClaw** and **PhoneBot** natively on Android devices using **Termux** and **Shizuku** — **no root required**.

This project patches Node.js version constraints, links Shizuku ADB privileges directly to Termux, and injects a complete phone automation toolset (phone\_control.sh) for AI agents.

## **⚡ Quick Start**

### **1\. Prerequisites (First-Time Termux Setup)**

On a fresh installation of Termux, grant storage access and install curl:

termux-setup-storage  
pkg update && pkg install \-y curl

### **2\. Run One-Line Installer**

Run the automated installer script (non-interactive, fully hands-free):

curl \-sL https://raw.githubusercontent.com/mhmdans/openclaw\_android/main/install.sh | bash

## **🚀 Post-Installation Steps**

After the installer displays 🎉 INSTALLATION COMPLETE\!, follow these steps to link ADB privileges and test your setup:

### **1\. Enable Shizuku Wireless Debugging (Android 11+)**

* Make sure **Wireless Debugging** is enabled in Android Developer Options.  
* Open the **Shizuku** app on your phone and start the service.

### **2\. Connect Shizuku to Termux**

Run the local auto-connector script inside Termux:

shizuku

*(This automatically scans local ports 30000–50000 and establishes the ADB connection).*

### **3\. Verify Phone Control**

Test if the phone controller bridge is active:

bash \~/phone\_control.sh battery

## **📱 Android 10 & Lower Setup (No Wireless Debugging)**

Android 10 and below do not support native Wireless Debugging. Follow these steps to set up **Shizuku**, **Termux**, and **Phone Control** using your PC:

### **1\. Start Shizuku via PC ADB**

1. Enable **USB Debugging** in your phone's Developer Options.  
2. Connect your phone to your PC via USB cable.  
3. Open **Shizuku** on your phone.  
4. On your PC, run the Shizuku start script via ADB:  
   adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/files/start.sh

5. Ensure Shizuku displays **"Shizuku is running"**.

### **2\. Export rish to Termux**

1. Open the **Shizuku** app on your phone.  
2. Tap **Use Shizuku in terminal apps** ![][image1] **Export files**.  
3. Save the files inside a folder named Shizuku in your phone's main internal storage (/sdcard/Shizuku/).  
4. Open **Termux** and run:  
   termux-setup-storage  
   cp \~/storage/shared/Shizuku/rish\_shizuku.dex $HOME/rish\_shizuku.dex

   cat \> /data/data/com.termux/files/usr/bin/rish \<\< 'EOF'  
   \#\!/data/data/com.termux/files/usr/bin/bash  
   \[ \-z "$RISH\_APPLICATION\_ID" \] && export RISH\_APPLICATION\_ID="com.termux"  
   /system/bin/app\_process \-Djava.class.path="$HOME/rish\_shizuku.dex" /system/bin \--nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "$@"  
   EOF

   chmod \+x /data/data/com.termux/files/usr/bin/rish

5. Verify ADB link inside Termux:  
   rish \-c "id"

   *(Accept the Shizuku authorization prompt on screen if asked. Output should show uid=2000(shell)).*

### **3\. Install Phone Control Script**

If curl throws SSL/QUIC errors in Termux, update package lists using apt and download using wget:

apt update && apt upgrade \-y  
apt install \-y wget

wget \-O \~/phone\_control.sh https://raw.githubusercontent.com/mhmdans/openclaw\_android/main/phone\_control.sh  
chmod \+x \~/phone\_control.sh

### **4\. Verify Setup**

Run the battery test script to confirm ADB communication:

bash \~/phone\_control.sh battery

## **🛠 Features & Installed Tooling**

| Component | Description |
| :---- | :---- |
| **shizuku / rish** | Enables elevated shell execution without requiring root access. |
| **phone\_control.sh** | Native CLI tool for screen taps, swipes, app launching, key events, and dumping UI XML hierarchies. |
| **OpenClaw Engine** | Installed and patched to bypass Node.js engine version constraints on Android. |
| **PhoneBot Identity** | Pre-configured workspace files inside \~/.openclaw/workspace/ (IDENTITY.md, TOOLS.md, AGENTS.md). |

## **🎮 Available Phone Controls**

You can control your device programmatically using \~/phone\_control.sh:

\# UI Interactions  
bash \~/phone\_control.sh tap \<x\> \<y\>  
bash \~/phone\_control.sh swipe \<x1\> \<y1\> \<x2\> \<y2\> \[duration\_ms\]  
bash \~/phone\_control.sh text "Hello World"  
bash \~/phone\_control.sh screenshot /sdcard/screen.png

\# System & Apps  
bash \~/phone\_control.sh open-app \<package.name\>  
bash \~/phone\_control.sh youtube-search "OpenAI Agents"  
bash \~/phone\_control.sh battery  
bash \~/phone\_control.sh wifi \[on|off\]

\# Hardware Key Events  
bash \~/phone\_control.sh home  
bash \~/phone\_control.sh back  
bash \~/phone\_control.sh recent  
bash \~/phone\_control.sh power  
bash \~/phone\_control.sh volume-up  
bash \~/phone\_control.sh volume-down

\# UI Automation Dump (Extracts text and screen bounds)  
bash \~/phone\_control.sh ui-dump

## **📄 License**

Distributed under the MIT License. See LICENSE for more information.

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAZCAYAAADe1WXtAAAAq0lEQVR4XmNgGAWjYGCBsrKyrLy8fLeCggIHuhzZQElJiR9o6GYg1kSXowjIycmVgzC6OMVAUVHRTEZGRgVdHA5ERUV5gN6RJBUDXfsISCcBDedEN5MBGOgVIAWkYqCB/4H4FVB/PLqZZAFxcXFuoIF9WF1JJmABGjgVSDOiS5ALWIDeXQjEHugSZAOgd6WBrtwsJSUlgi5HNjA2NmYFGizEQEWvj4JRQAAAAF1pKp6Jr3nrAAAAAElFTkSuQmCC>