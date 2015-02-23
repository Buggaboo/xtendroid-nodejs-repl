package nl.sison.android.nodejs.repl

import org.xtendroid.annotations.AndroidPreference

@AndroidPreference class Settings
{
    boolean drawerLearned = false
    
    boolean accelerometerService = false
    boolean ambientTemperatureService = false
    boolean gameRotationVectorService = false
    boolean geoMagneticRotationVectorService = false
    boolean gravityService = false
    boolean gyroscopeService = false
    boolean gyroscopeUncalibratedService = false
    boolean heartRateService = false
    boolean lightService = false
    boolean linearAccelerationService = false
    boolean magneticFieldService = false
    boolean magneticFieldUncalibratedService = false
    boolean pressureService = false
    boolean proximityService = false
    boolean relativeHumidityService = false
    boolean rotationVectorService = false
    boolean significantMotionService = false
    boolean stepCounterService = false
    boolean stepDetectorService = false
}
