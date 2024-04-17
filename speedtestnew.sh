#!/bin/bash

#Get System hostname
devicename=$(hostname)
echo "DeviceNmae: $devicename"

#Get System Serialnumber
serialnumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
echo "Serialnumber: $serialnumber"

# Function to get network quality and extract capacity values
get_network_quality() {
    output=$(networkQuality -s)
    uplink=$(echo "$output" | grep "Uplink capacity" | awk '{print $3}')
    downlink=$(echo "$output" | grep "Downlink capacity" | awk '{print $3}')
}

# Get WiFi SSID
wifiSSID=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}' | xargs networksetup -getairportnetwork | awk -F': ' '/Current Wi-Fi Network: /{print $2}'
)
echo "WiFiSSID: $wifiSSID"

# Conditionally set uplink and downlink based on WiFi SSID
if [[ "$wifiSSID" == "Anywhereworks" ]]; then
    uplink="office"
    downlink="office"
else
    # Get network quality and extract capacity values
    get_network_quality
fi

# Display the extracted information
echo "Uplink Capacity: $uplink"
echo "Downlink Capacity: $downlink"

# Ping google.com and capture latency
ping_result=$(ping -c 15 1.1.1.1 | grep 'min/avg/max/stddev')

# Extract minimum, average, and maximum latency from ping result
min_latency=$(echo "$ping_result" | awk -F'/' '{print $4}')
# Remove "stddev =" from min_latency
min_latency=$(echo "$min_latency" | sed 's/stddev = //')
avg_latency=$(echo "$ping_result" | awk -F'/' '{print $5}')
max_latency=$(echo "$ping_result" | awk -F'/' '{print $6}')

# Display latency values
echo "Minimum latency to google.com: $min_latency"
echo "Average latency to google.com: $avg_latency"
echo "Maximum latency to google.com: $max_latency"

# Perform specific action based on WiFi SSID
if [[ "$wifiSSID" == "Anywhereworks" ]]; then
    echo "Marking latencies as office..."
    min_latency="office"
    avg_latency="office"
    max_latency="office"
else
    echo "Running additional latency extraction..."
    # Extract additional latency information or perform other actions
    # (This part can be filled in with additional logic as needed)
fi

# Display updated latency values after condition
echo "Updated Minimum latency: $min_latency"
echo "Updated Average latency: $avg_latency"
echo "Updated Maximum latency: $max_latency"


#check the networkport
while read -r line; do
    sname=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $2}')
    sdev=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $4}')
    #echo "Current service: $sname, $sdev, $currentservice"
    if [ -n "$sdev" ]; then
        ifout="$(ifconfig "$sdev" 2>/dev/null)"
        echo "$ifout" | grep 'status: active' > /dev/null 2>&1
        rc="$?"
        if [ "$rc" -eq 0 ]; then
            currentservice="$sname"
            currentdevice="$sdev"
            currentmac=$(echo "$ifout" | awk '/ether/{print $2}')

            # may have multiple active devices, so echo it here
            echo "$currentservice, $currentdevice, $currentmac"
        fi
    fi
done <<< "$(networksetup -listnetworkserviceorder | grep 'Hardware Port')"

if [ -z "$currentservice" ]; then
    >&2 echo "Could not find current service"
    exit 1
fi

# Capture current date and time in IST format
current_ist_date=$(TZ=":Asia/Kolkata" date +"%Y-%m-%d")
current_ist_time=$(TZ=":Asia/Kolkata" date +"%H:%M:%S")

# Print the captured date and time
echo "date_value: $current_ist_date"
echo "time_value: $current_ist_time"

# Cloud Function URL
FUNCTION_URL="https://us-central1-sumitha-testing.cloudfunctions.net/speedtest"

# Data to be sent in the request
DATA='{"uplink": "'"$uplink"'", "downlink_capacity": "'"$downlink"'"}'
echo $DATA
# Make an HTTP POST request using curl
#result = $(curl -X GET --header "Accept: */*" "$FUNCTION_URL/$uplink_capacity")
#echo $result
#exit
echo $devicename
echo $currentservice

result= $(curl --location 'https://us-central1-sumitha-testing.cloudfunctions.net/speedtest' \
--header 'Content-Type: application/json' \
--data '{
    "uplink":"'"$uplink"'",
    "downlink":"'"$downlink"'",
    "devicename":"'"$devicename"'",
    "currentservice":"'"$currentservice"'",
    "min_latency":"'"$min_latency"'",
    "avg_latency":"'"$avg_latency"'",
    "max_latency":"'"$max_latency"'",
    "date_value":"'"$current_ist_date"'",
    "time_value":"'"$current_ist_time"'",
    "serialnumber":"'"$serialnumber"'",
    "wifiSSID":"'"$wifiSSID"'"        
}')
echo $result
exit
