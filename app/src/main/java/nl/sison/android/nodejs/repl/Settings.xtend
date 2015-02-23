package nl.sison.android.nodejs.repl

import org.xtendroid.annotations.AndroidPreference

@AndroidPreference class Settings
{
    boolean drawerLearned = false
    
    boolean accelerometer = false
    boolean ambientTemperature = false
    boolean gameRotationVector = false
    boolean geoMagneticRotationVector = false
    boolean gravity = false
    boolean gyroscope = false
    boolean gyroscopeUncalibrated = false
    boolean heartRate = false
    boolean light = false
    boolean linearAcceleration = false
    boolean magneticField = false
    boolean magneticFieldUncalibrated = false
    boolean pressure = false
    boolean proximity = false
    boolean relativeHumidity = false
    boolean rotationVector = false
    boolean significantMotion = false
    boolean stepCounter = false
    boolean stepDetector = false

    /** Because Xtendroid stores the String keys as snake case */
    static def snakeCase(String ssss)
    {
        ssss.replaceAll("(.)(\\p{Upper})", "$1_$2").toLowerCase
    }
}
