package nl.sison.android.nodejs.sensors

import android.app.Service
import android.content.Intent

import android.net.LocalSocket

import android.net.LocalSocketAddress
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

import android.system.Os
import android.system.OsConstants
import java.io.FileDescriptor

import java.io.File
import java.io.IOException

import nl.sison.android.nodejs.repl.NodeJNI


// Gradle bug, after project clean, MIA, specific for android
import nl.sison.android.nodejs.BuildConfig

import org.xtendroid.annotations.AddLogTag

import java.lang.reflect.Method


@AddLogTag
class NodeSensorBaseService extends Service implements SensorEventListener {

    Handler mainHandler = new Handler(Looper.getMainLooper())

    override onBind(Intent intent)
    {
        return null // we will not bind this
    }

    protected Sensor mSensor
    protected SensorManager mSensorManager
    protected var SENSOR_TYPE = Sensor.TYPE_ALL
    protected var SENSOR_TYPE_NAME = 'ALL'
    protected val SENSOR_DELAY = SensorManager.SENSOR_DELAY_NORMAL
    protected def void startSensor(int sensorType, String sensorTypeName)
    {
        // Caveat: there could be multiple sensors of a type,
        // this implementation assumes there is one of each type
        // feel free to override :)
        // /data/data/nl.sison.android.nodejs.repl/cache/sensor_sockets.TYPE/ALL
        Log.d(TAG, 'Getting sensor service: ' + sensorTypeName)
        mSensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        var sensorList = mSensorManager.getSensorList(sensorType)

        if (sensorList.size > 0)
        {
            //mainHandler.post[ Log.i(TAG, String.format('There are multiple sensors for the %s sensor', SENSOR_TYPE_NAME)) ]
            sensorList.forEach[ s |
                Log.i(TAG, String.format('available %s sensor: %s', sensorTypeName, s.name))
            ]
        }

        mSensor = mSensorManager.getDefaultSensor(sensorType)

        if (mSensor != null)
        {
            mSensorManager.registerListener(this, mSensor, SENSOR_DELAY)
            Log.d(TAG, 'Running sensor service: ' + sensorTypeName)
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
    val SOCKET_STREAM = 2
    val BACK_LOG = 50
    var FileDescriptor mFileDescriptor
    protected def startLocalServerSocket(String sensorTypeName)
    {
        // /data/data/nl.sison.android.nodejs.repl/cache/sensor_sockets/TYPE_ALL.sock
        val location = TextUtils.concat(cacheDir.toString, '/sensor_sockets/TYPE_', sensorTypeName, '.sock').toString
        Log.d(TAG + ' location', location)

        // connect the path inbetween
        new File(location.replace(sensorTypeName + '.sock', '')).mkdirs

        try {
            new Thread[
                mLocalServerSocket =
                    new LocalServerSocket(NodeJNI.createLocalSocket(location).createFileDescriptor)
                // The following will block, so no funky busy loops with sleep necessary
                mLocalSocketSender = mLocalServerSocket.accept
            ].start

            // TODO start NodeJNI client, use process.argv to pass on the intended path

        }catch (IOException e)
        {
            Log.e(TAG, e.message)
            stopSelf
        }
    }

    /**
	 * Leverage reflection to call ZygoteInit#createFileDescriptor, even GingerBread has it
	 */
	static def createFileDescriptor(int fdi)
	{
        var cls = Class.forName('com.android.internal.os.ZygoteInit')
        val method = cls.getDeclaredMethod('createFileDescriptor', Integer.TYPE)
        method.accessible = true
        return method.invoke(null, #[ fdi ]) as FileDescriptor
	}

    override onCreate()
    {
        super.onCreate
        startSensor(SENSOR_TYPE, SENSOR_TYPE_NAME) // if it's not available, just GTFO
        startLocalServerSocket(SENSOR_TYPE_NAME)
    }

    override int onStartCommand(Intent intent, int flags, int startId)
    {
		super.onStartCommand(intent, flags, startId)
		return START_STICKY
    }

    override onSensorChanged(SensorEvent event)
    {
        if (mLocalSocketSender != null && mLocalSocketSender.connected) // implies there is a connection with a client
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

    /**
    Activate with:
        var net = require('net');
        var conn = net.createConnection('/data/data/nl.sison.android.nodejs.repl/cache/sensor_sockets/TYPE_ALL.sock');
        conn.on('connect', function() { console.log('connected to unix socket server');});
        conn.on('data', function () { console.log(data) });

    */
    static def jsonify(SensorEvent event)
    {
        val objSensor = new JSONObject
        val sensor = event.sensor

        objSensor.put('type', sensor.type)
        .put('name', sensor.name)
        .put('stringType', try { sensor.stringType }catch (NoSuchMethodError e) { 'null' } ) // unsupported by my Samsung tablet for some reason
        .put('fifoMaxEventCount', sensor.fifoMaxEventCount)
        .put('fifoReservedEventCount', sensor.fifoReservedEventCount)
        .put('maxDelay', try { sensor.maxDelay }catch (NoSuchMethodError e) { 'null' } ) // unsupported by my Samsung tablet for some reason
        .put('minDelay', sensor.minDelay)
        .put('power', sensor.power)
        .put('reportingMode', try { sensor.reportingMode }catch (NoSuchMethodError e) { 'null' } )
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
        Log.d(TAG, 'Destroying sensor service: ' + SENSOR_TYPE_NAME)
        if (mLocalServerSocket != null)
            { mLocalServerSocket.close }
        mSensorManager.unregisterListener(this)
    }
}

/** TYPE_ALL 	A constant describing all sensor types.
 * This was intended as a pre-scan of available Sensors */
class SensorService extends NodeSensorBaseService
{
    var sepukuHandler = new Handler
    override void startSensor(int type, String name)
    {
        super.startSensor(type, name)
        // TODO
        // Highlight actual working sensors, deactivate unsupported ones
        sepukuHandler.postDelayed([ stopSelf ], 300000)
    }
}

/** TYPE_ACCELEROMETER 	A constant describing an accelerometer sensor type. */
class AccelerometerService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_ACCELEROMETER
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_ACCELEROMETER
}

/** TYPE_AMBIENT_TEMPERATURE 	A constant describing an ambient temperature sensor type. */
class AmbientTemperatureService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_AMBIENT_TEMPERATURE
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_AMBIENT_TEMPERATURE
}

/** TYPE_GAME_ROTATION_VECTOR 	A constant describing an uncalibrated rotation vector sensor type. */
class GameRotationVectorService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_GAME_ROTATION_VECTOR
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GAME_ROTATION_VECTOR
}

/** TYPE_GEOMAGNETIC_ROTATION_VECTOR 	A constant describing a geo-magnetic rotation vector. */
class GeoMagneticRotationVectorService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GEOMAGNETIC_ROTATION_VECTOR
}

/** TYPE_GRAVITY 	A constant describing a gravity sensor type. */
class GravityService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_GRAVITY
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GRAVITY
}

/** TYPE_GYROSCOPE 	A constant describing a gyroscope sensor type. */
class GyroscopeService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_GYROSCOPE
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GYROSCOPE
}

/** TYPE_GYROSCOPE_UNCALIBRATED 	A constant describing an uncalibrated gyroscope sensor type. */
class GyroscopeUncalibratedService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_GYROSCOPE_UNCALIBRATED
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_GYROSCOPE_UNCALIBRATED
}

/** TYPE_HEART_RATE 	A constant describing a heart rate monitor. */
class HeartRateService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_HEART_RATE
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_HEART_RATE
}

/** TYPE_LIGHT 	A constant describing a light sensor type. */
class LightService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_LIGHT
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_LIGHT
}

/** TYPE_LINEAR_ACCELERATION 	A constant describing a linear acceleration sensor type. */
class LinearAccelerationService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_LINEAR_ACCELERATION
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_LINEAR_ACCELERATION
}

/** TYPE_MAGNETIC_FIELD 	A constant describing a magnetic field sensor type. */
class MagneticFieldService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_MAGNETIC_FIELD
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_MAGNETIC_FIELD
}

/** TYPE_MAGNETIC_FIELD_UNCALIBRATED 	A constant describing an uncalibrated magnetic field sensor type. */
class MagneticFieldUncalibratedService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_MAGNETIC_FIELD_UNCALIBRATED
}

/** TYPE_ORIENTATION 	This constant was deprecated in API level 8. use SensorManager.getOrientation() instead. */

/** TYPE_PRESSURE 	A constant describing a pressure sensor type. */
class PressureService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_PRESSURE
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_PRESSURE
}

/** TYPE_PROXIMITY 	A constant describing a proximity sensor type. */
class ProximityService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_PROXIMITY
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_PROXIMITY
}

/** TYPE_RELATIVE_HUMIDITY 	A constant describing a relative humidity sensor type. */
class RelativeHumidityService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_RELATIVE_HUMIDITY
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_RELATIVE_HUMIDITY
}

/** TYPE_ROTATION_VECTOR 	A constant describing a rotation vector sensor type. */
class RotationVectorService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_ROTATION_VECTOR
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_ROTATION_VECTOR
}

/** TYPE_SIGNIFICANT_MOTION 	A constant describing a significant motion trigger sensor. */
class SignificantMotionService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_SIGNIFICANT_MOTION
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_SIGNIFICANT_MOTION
}

/** TYPE_STEP_COUNTER 	A constant describing a step counter sensor. */
class StepCounterService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_STEP_COUNTER
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_STEP_COUNTER
}

/** TYPE_STEP_DETECTOR 	A constant describing a step detector sensor. */
class StepDetectorService extends NodeSensorBaseService
{
    protected var SENSOR_TYPE = Sensor.TYPE_STEP_DETECTOR
    protected var SENSOR_TYPE_NAME = Sensor.STRING_TYPE_STEP_DETECTOR
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

// TODO - NFC, Bluetooth, Camera, Sound IO, ...
// Design ideas: only turn on services, that the user actually wants to use at that time.
// Do not start stuff by default.