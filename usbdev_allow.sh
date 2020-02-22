#!/bin/sh

# Input should be a single line from lsusb output
DATA=`lsusb | grep $1`

if [ -z "$DATA" ]; then
	echo 'ERROR: USB device not found !'
	exit
fi

# Read the bus number
BUS=`echo $DATA | awk '{print $2}'`

# Read the device number
DEV=`echo $DATA | awk '{print $4}' RS=':'`

USB_FILE="/dev/bus/usb/$BUS/$DEV"

echo "USB device $1 found in $USB_FILE, allowing write access"
chmod o+w $USB_FILE
