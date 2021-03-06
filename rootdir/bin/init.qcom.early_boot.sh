#! /vendor/bin/sh

# Copyright (c) 2012-2013,2016,2018 The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Set platform variables
if [ -f /sys/devices/soc0/hw_platform ]; then
    soc_hwplatform=`cat /sys/devices/soc0/hw_platform` 2> /dev/null
else
    soc_hwplatform=`cat /sys/devices/system/soc/soc0/hw_platform` 2> /dev/null
fi
if [ -f /sys/devices/soc0/soc_id ]; then
    soc_hwid=`cat /sys/devices/soc0/soc_id` 2> /dev/null
else
    soc_hwid=`cat /sys/devices/system/soc/soc0/id` 2> /dev/null
fi
if [ -f /sys/devices/soc0/platform_version ]; then
    soc_hwver=`cat /sys/devices/soc0/platform_version` 2> /dev/null
else
    soc_hwver=`cat /sys/devices/system/soc/soc0/platform_version` 2> /dev/null
fi

if [ -f /sys/class/drm/card0-DSI-1/modes ]; then
    echo "detect" > /sys/class/drm/card0-DSI-1/status
    mode_file=/sys/class/drm/card0-DSI-1/modes
    while read line; do
        fb_width=${line%%x*};
        break;
    done < $mode_file
elif [ -f /sys/class/graphics/fb0/virtual_size ]; then
    res=`cat /sys/class/graphics/fb0/virtual_size` 2> /dev/null
    fb_width=${res%,*}
fi

log -t BOOT -p i "MSM target '$1', SoC '$soc_hwplatform', HwID '$soc_hwid', SoC ver '$soc_hwver'"

#For drm based display driver
vbfile=/sys/module/drm/parameters/vblankoffdelay
if [ -w $vbfile ]; then
    echo -1 >  $vbfile
else
    log -t DRM_BOOT -p w "file: '$vbfile' or perms doesn't exist"
fi

function set_density_by_fb() {
    #put default density based on width
    if [ -z $fb_width ]; then
        setprop vendor.display.lcd_density 320
    else
        if [ $fb_width -ge 1600 ]; then
           setprop vendor.display.lcd_density 640
        elif [ $fb_width -ge 1440 ]; then
           setprop vendor.display.lcd_density 560
        elif [ $fb_width -ge 1080 ]; then
           setprop vendor.display.lcd_density 480
        elif [ $fb_width -ge 720 ]; then
           setprop vendor.display.lcd_density 320 #for 720X1280 resolution
        elif [ $fb_width -ge 480 ]; then
            setprop vendor.display.lcd_density 240 #for 480X854 QRD resolution
        else
            setprop vendor.display.lcd_density 160
        fi
    fi
}

target=`getprop ro.board.platform`
case "$target" in
    "msm8996")
        case "$soc_hwplatform" in
            "Dragon")
                setprop vendor.display.lcd_density 240
                setprop qemu.hw.mainkeys 0
                ;;
            "ADP")
                setprop vendor.display.lcd_density 160
                setprop qemu.hw.mainkeys 0
                ;;
            "SBC")
                setprop vendor.display.lcd_density 240
                setprop qemu.hw.mainkeys 0
                ;;
            *)
                setprop vendor.display.lcd_density 560
                ;;
        esac
        ;;
esac

baseband=`getprop ro.baseband`
#enable atfwd daemon all targets except sda, apq, qcs
case "$baseband" in
    "apq" | "sda" | "qcs" )
        setprop persist.vendor.radio.atfwd.start false;;
    *)
        setprop persist.vendor.radio.atfwd.start true;;
esac

#set default lcd density
#Since lcd density has read only
#property, it will not overwrite previous set
#property if any target is setting forcefully.
set_density_by_fb

# Setup display nodes & permissions
# HDMI can be fb1 or fb2
# Loop through the sysfs nodes and determine
# the HDMI(dtv panel)

##### moved to init.target.rc (booting performance team)#####
#function set_perms() {
#    #Usage set_perms <filename> <ownership> <permission>
#    chown -h $2 $1
#    chmod $3 $1
#}
#
#function setHDMIPermission() {
#   file=/sys/class/graphics/fb$1
#   dev_file=/dev/graphics/fb$1
#   dev_gfx_hdmi=/devices/virtual/switch/hdmi
#
#   set_perms $file/hpd system.graphics 0664
#   set_perms $file/res_info system.graphics 0664
#   set_perms $file/vendor_name system.graphics 0664
#   set_perms $file/product_description system.graphics 0664
#   set_perms $file/video_mode system.graphics 0664
#   set_perms $file/format_3d system.graphics 0664
#   set_perms $file/s3d_mode system.graphics 0664
#   set_perms $file/dynamic_fps system.graphics 0664
#   set_perms $file/msm_fb_dfps_mode system.graphics 0664
#   set_perms $file/hdr_stream system.graphics 0664
#   set_perms $file/cec/enable system.graphics 0664
#   set_perms $file/cec/logical_addr system.graphics 0664
#   set_perms $file/cec/rd_msg system.graphics 0664
#   set_perms $file/pa system.graphics 0664
#   set_perms $file/cec/wr_msg system.graphics 0600
#   set_perms $file/hdcp/tp system.graphics 0664
#   set_perms $file/hdcp2p2/min_level_change system.graphics 0660
#   set_perms $file/hdmi_audio_cb audioserver.audio 0600
#   ln -s $dev_file $dev_gfx_hdmi
#}

# check for the type of driver FB or DRM
fb_driver=/sys/class/graphics/fb0
if [ -e "$fb_driver" ]
then
#    # check for HDMI connection
#    for fb_cnt in 0 1 2 3
#    do
#        file=/sys/class/graphics/fb$fb_cnt/msm_fb_panel_info
#        if [ -f "$file" ]
#        then
#          cat $file | while read line; do
#            case "$line" in
#                *"is_pluggable"*)
#                 case "$line" in
#                      *"1"*)
#                      setHDMIPermission $fb_cnt
#                 esac
#            esac
#          done
#        fi
#    done

    # check for mdp caps
    file=/sys/class/graphics/fb0/mdp/caps
    if [ -f "$file" ]
    then
        setprop vendor.gralloc.disable_ubwc 1
        cat $file | while read line; do
          case "$line" in
                    *"ubwc"*)
                    setprop vendor.gralloc.enable_fb_ubwc 1
                    setprop vendor.gralloc.disable_ubwc 0
                esac
        done
    fi
#    file=/sys/class/graphics/fb0
#    if [ -d "$file" ]
#    then
#            set_perms $file/idle_time system.graphics 0664
#            set_perms $file/dynamic_fps system.graphics 0664
#            set_perms $file/dyn_pu system.graphics 0664
#            set_perms $file/modes system.graphics 0664
#            set_perms $file/mode system.graphics 0664
#            set_perms $file/msm_cmd_autorefresh_en system.graphics 0664
#    fi
#
#    # set lineptr permissions for all displays
#    for fb_cnt in 0 1 2 3
#    do
#        file=/sys/class/graphics/fb$fb_cnt
#        if [ -f "$file/lineptr_value" ]; then
#            set_perms $file/lineptr_value system.graphics 0664
#        fi
#        if [ -f "$file/msm_fb_persist_mode" ]; then
#            set_perms $file/msm_fb_persist_mode system.graphics 0664
#        fi
#    done
#else
#    set_perms /sys/devices/virtual/hdcp/msm_hdcp/min_level_change system.graphics 0660
fi

boot_reason=`cat /proc/sys/kernel/boot_reason`
reboot_reason=`getprop ro.boot.alarmboot`
if [ "$boot_reason" = "3" ] || [ "$reboot_reason" = "true" ]; then
    setprop ro.vendor.alarm_boot true
else
    setprop ro.vendor.alarm_boot false
fi

# copy GPU frequencies to vendor property
if [ -f /sys/class/kgsl/kgsl-3d0/gpu_available_frequencies ]; then
    gpu_freq=`cat /sys/class/kgsl/kgsl-3d0/gpu_available_frequencies` 2> /dev/null
    setprop vendor.gpu.available_frequencies "$gpu_freq"
fi
