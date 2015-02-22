package nl.sison.android.nodejs.sensors

import android.app.Service
import android.content.Intent

import android.net.LocalSocket
import android.net.LocalServerSocket
import android.text.TextUtils

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

import org.json.JSONArray
import org.json.JSONObject

import android.os.Looper
import android.os.Handler
import android.util.Log

// Gradle bug, after project clean, MIA, specific for android
import nl.sison.android.nodejs.BuildConfig

import org.xtendroid.annotations.AddLogTag


@AddLogTag
class NodeSensorBaseService extends Service implements SensorEventListener {

    Handler mainHandler = new Handler(Looper.getMainLooper())

    override onBind(Intent intent)
    {
        return null // we will not bind this
    }

    Sensor mSensor
    SensorManager mSensorManager
    protected val SENSOR_TYPE = -1 // -1 implies all sensors, override for a specific type
    protected val SENSOR_DELAY = SensorManager.SENSOR_DELAY_NORMAL
    protected def void startSensor()
    {
        // Caveat: there could be multiple sensors of a type,
        // this implementation assumes there is one of each type
        // feel free to override :)
        mainHandler.post[ Log.d(TAG, 'Getting sensor service: ' + SENSOR_TYPE_NAME) ]
        mSensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        mSensor = mSensorManager.getDefaultSensor(SENSOR_TYPE);
        if (mSensor != null)
        {
            mSensorManager.registerListener(this, mSensor, SENSOR_DELAY)
            mainHandler.post[ Log.d(TAG, 'Running sensor service: ' + SENSOR_TYPE_NAME) ]
        }else
            {stopSelf} // harakiri
    }

    val bufSize = 1024 // hopefully this is more than enuff
    LocalServerSocket mLocalServerSocket
    LocalSocket       mLocalSocketSender

    /**
     * Must overload to determine the type of sensor being started
     * and differentiate the domain socket (abstract or not)
     */
    protected val SENSOR_TYPE_NAME = ''
    def startLocalServerSocket()
    {
        var sensorType = if (TextUtils.isEmpty(SENSOR_TYPE_NAME)) 'ALL' else SENSOR_TYPE_NAME

        mLocalServerSocket= new LocalServerSocket(
            TextUtils.concat(cacheDir.toString, '/sensor_sockets/TYPE_', sensorType).toString)

        // The following will block, so no funky busy loops with sleep necessary
        mLocalSocketSender = mLocalServerSocket.accept
    }

    override onCreate()
    {
        super.onCreate()
        startSensor // if it's not available, just GTFO
        startLocalServerSocket
    }

    override int onStartCommand(Intent intent, int flags, int startId)
    {
		super.onStartCommand(intent, flags, startId)
		return START_STICKY
    }

    override onSensorChanged(SensorEvent event)
    {
        if (mLocalSocketSender != null) // implies there is a connection with a client
        {
            var out = mLocalSocketSender.outputStream
            out.write(jsonify(event))
            out.close
        }
    }

    override onAccuracyChanged(Sensor sensor, int accuracy)
    {
        // intentionally not implemented
    }

    static def jsonify(SensorEvent event)
    {
        val objSensor = new JSONObject
        val sensor = event.sensor
        objSensor.put('type', sensor.type)
        .put('name', sensor.name)
        //.put('stringType', sensor.stringType) // unsupported by my Samsung tablet for some reason
        .put('fifoMaxEventCount', sensor.fifoMaxEventCount)
        .put('fifoReservedEventCount', sensor.fifoReservedEventCount)
//        .put('maxDelay', sensor.maxDelay) // unsupported by my Samsung tablet for some reason
        .put('minDelay', sensor.minDelay)
        .put('power', sensor.power)
        .put('reportingMode', sensor.reportingMode)
        .put('maximumRange', sensor.maximumRange)
        .put('resolution', sensor.resolution)
        .put('vendor', sensor.vendor)
        .put('version', sensor.version)
        .put('wakeUpSensor', sensor.wakeUpSensor)


        val obj = new JSONObject
        obj.put('sensor', objSensor)
        .put('accuracy', event.accuracy)
        .put('timestamp', event.timestamp)
        .put('values', new JSONArray(event.values))
        return obj.toString.getBytes('UTF-8')
    }

    override onDestroy()
    {
        super.onDestroy
        mainHandler.post[ Log.d(TAG, 'Destroying sensor service: ' + SENSOR_TYPE_NAME) ]
        mSensorManager.unregisterListener(this)
    }
}

/** TYPE_ALL 	A constant describing all sensor types. */

/** TYPE_ACCELEROMETER 	A constant describing an accelerometer sensor type. */
class AccelerometerService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_ACCELEROMETER
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_ACCELEROMETER
}

/** TYPE_AMBIENT_TEMPERATURE 	A constant describing an ambient temperature sensor type. */
class AmbientTemperatureService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_AMBIENT_TEMPERATURE
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_AMBIENT_TEMPERATURE
}

/** TYPE_GAME_ROTATION_VECTOR 	A constant describing an uncalibrated rotation vector sensor type. */
class GameRotationVectorService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_GAME_ROTATION_VECTOR
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GAME_ROTATION_VECTOR
}

/** TYPE_GEOMAGNETIC_ROTATION_VECTOR 	A constant describing a geo-magnetic rotation vector. */
class GeoMagneticRotationVectorService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GEOMAGNETIC_ROTATION_VECTOR
}

/** TYPE_GRAVITY 	A constant describing a gravity sensor type. */
class GravityService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_GRAVITY
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GRAVITY
}

/** TYPE_GYROSCOPE 	A constant describing a gyroscope sensor type. */
class GyroscopeService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_GYROSCOPE
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GYROSCOPE
}

/** TYPE_GYROSCOPE_UNCALIBRATED 	A constant describing an uncalibrated gyroscope sensor type. */
class GyroscopeUncalibratedService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_GYROSCOPE_UNCALIBRATED
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GYROSCOPE_UNCALIBRATED
}

/** TYPE_HEART_RATE 	A constant describing a heart rate monitor. */
class HeartRateService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_HEART_RATE
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_HEART_RATE
}

/** TYPE_LIGHT 	A constant describing a light sensor type. */
class LightService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_LIGHT
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_LIGHT
}

/** TYPE_LINEAR_ACCELERATION 	A constant describing a linear acceleration sensor type. */
class LinearAccelerationService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_LINEAR_ACCELERATION
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_LINEAR_ACCELERATION
}

/** TYPE_MAGNETIC_FIELD 	A constant describing a magnetic field sensor type. */
class MagneticFieldService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_MAGNETIC_FIELD
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_MAGNETIC_FIELD
}

/** TYPE_MAGNETIC_FIELD_UNCALIBRATED 	A constant describing an uncalibrated magnetic field sensor type. */
class MagneticFieldUncalibratedService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_MAGNETIC_FIELD_UNCALIBRATED
}

/** TYPE_ORIENTATION 	This constant was deprecated in API level 8. use SensorManager.getOrientation() instead. */

/** TYPE_PRESSURE 	A constant describing a pressure sensor type. */
class PressureService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_PRESSURE
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_PRESSURE
}

/** TYPE_PROXIMITY 	A constant describing a proximity sensor type. */
class ProximityService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_PROXIMITY
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_PROXIMITY
}

/** TYPE_RELATIVE_HUMIDITY 	A constant describing a relative humidity sensor type. */
class RelativeHumidityService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_RELATIVE_HUMIDITY
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_RELATIVE_HUMIDITY
}

/** TYPE_ROTATION_VECTOR 	A constant describing a rotation vector sensor type. */
class RotationVectorService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_ROTATION_VECTOR
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_ROTATION_VECTOR
}

/** TYPE_SIGNIFICANT_MOTION 	A constant describing a significant motion trigger sensor. */
class SignificantMotionService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_SIGNIFICANT_MOTION
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_SIGNIFICANT_MOTION
}

/** TYPE_STEP_COUNTER 	A constant describing a step counter sensor. */
class StepCounterService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_STEP_COUNTER
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_STEP_COUNTER
}

/** TYPE_STEP_DETECTOR 	A constant describing a step detector sensor. */
class StepDetectorService extends NodeSensorBaseService
{
    val SENSOR_TYPE = Sensor.TYPE_STEP_DETECTOR
    val SENSOR_TYPE_NAME = Sensor.STRING_TYPE_STEP_DETECTOR
}

/** TYPE_TEMPERATURE 	This constant was deprecated in API level 14. use Sensor.TYPE_AMBIENT_TEMPERATURE instead. */

// bash command to generate <service /> in AndroidManifest
// `which grep` class SensorServices.xtend  | sed 's/ extends.*/" \/>/;s/class /<service android:enabled="true" android:exported="false" android:isolatedProcess="true" android:name=".sensors./' | `which grep` -v BaseService >> meh.txt

// bash command to get <uses-feature... from sensors.txt:
// sed 's/[[:space:]]\+The.*//;s/\([A-Za-z\.]+\)/\1/' sensors.txt | sed 's/\(.*\)/<uses-feature android:name=\"\1\" android:required=\"false\" \/>/'

// sensors.txt
/*
android.hardware.sensor.accelerometer   The application uses motion readings from an accelerometer on the device.
android.hardware.sensor.barometer   The application uses the device's barometer.
android.hardware.sensor.compass     The application uses directional readings from a magnetometer (compass) on the device.
android.hardware.sensor.gyroscope   The application uses the device's gyroscope sensor.
android.hardware.sensor.light   The application uses the device's light sensor.
android.hardware.sensor.proximity   The application uses the device's proximity sensor.
android.hardware.sensor.stepcounter     The application uses the device's step counter.
android.hardware.sensor.stepdetector
*/