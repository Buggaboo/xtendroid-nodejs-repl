#!/bin/bash

for d in $(adb devices | /bin/grep -i "device$" | /bin/sed "s/[[:space:]]*device//"); do
  adb -s $d shell setprop debug.checkjni 1
  adb -s $d install -r ./app/build/outputs/apk/app-debug.apk
done
