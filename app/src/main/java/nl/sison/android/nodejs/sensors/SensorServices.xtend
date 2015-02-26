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
    protected val SENSOR_TYPE = Sensor.TYPE_ALL
    protected val SENSOR_DELAY = SensorManager.SENSOR_DELAY_NORMAL
    protected def void startSensor()
    {
        // Caveat: there could be multiple sensors of a type,
        // this implementation assumes there is one of each type
        // feel free to override :)
        // /data/data/nl.sison.android.nodejs.repl/cache/sensor_sockets.TYPE/ALL
        Log.d(TAG, 'Getting sensor service: ' + SENSOR_TYPE_NAME)
        mSensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        var sensorList = mSensorManager.getSensorList(SENSOR_TYPE)

        if (sensorList.size > 0)
        {
            //mainHandler.post[ Log.i(TAG, String.format('There are multiple sensors for the %s sensor', SENSOR_TYPE_NAME)) ]
            sensorList.forEach[ s |
                Log.i(TAG, String.format('available %s sensor: %s', SENSOR_TYPE_NAME, s.name))
            ]
        }

        mSensor = mSensorManager.getDefaultSensor(SENSOR_TYPE)

        if (mSensor != null)
        {
            mSensorManager.registerListener(this, mSensor, SENSOR_DELAY)
            Log.d(TAG, 'Running sensor service: ' + SENSOR_TYPE_NAME)
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
    protected val SENSOR_TYPE_NAME = 'ALL'
    val SOCKET_STREAM = 2
    val BACK_LOG = 50
    var FileDescriptor mFileDescriptor
    def startLocalServerSocket()
    {
        // /data/data/nl.sison.android.nodejs.repl/cache/sensor_sockets.TYPE/ALL
        var location = TextUtils.concat(cacheDir.toString, '/sensor_sockets.TYPE/', SENSOR_TYPE_NAME).toString
        try {
            val addr = new LocalSocketAddress(location, LocalSocketAddress.Namespace.FILESYSTEM)
/*
            // LocalSocketServer::new
            val clazz = Class.forName('android.net.LocalSocketImpl')
            val ctors = clazz.declaredConstructors

            ctors.forEach[ c | Log.d(TAG, c.toString) ]

            // Change the accessible property of the constructor.
            val ctor = ctors.get(0)
            ctor.accessible = true
            val impl = ctor.newInstance(null)

            clazz.methods.forEach[ m | Log.d(TAG, m.toString) ]

            val create = clazz.getDeclaredMethod('create', #[ Integer.TYPE ])
            create.invoke(impl, #[ SOCKET_STREAM ]) // 4.4: IOException no fd.

            Thread.sleep(2000)

            val bind = clazz.getDeclaredMethod('bind', #[ LocalSocketAddress ])
            bind.invoke(impl, #[ addr ])

            val listen = clazz.getDeclaredMethod('listen', #[ Integer.TYPE ])
            listen.invoke(impl, #[ BACK_LOG ])

            // LocalSocketServer::accept
            val impl2 = ctor.newInstance(null)
            val accept = clazz.getDeclaredMethod('accept', #[ clazz ])
            accept.invoke(impl, #[ impl2 ])

            //var ls = new LocalSocket(impl2, 2)
            val lsCtors = Class.forName('android.net.LocalSocket').declaredConstructors

            val lsCtor = lsCtors.get(3)
            lsCtor.accessible = true

            // The following will block, so no funky busy loops with sleep necessary
            mLocalSocketSender = lsCtor.newInstance(impl2, SOCKET_STREAM) as LocalSocket
*/
            // First attempt, starting the 2nd...
            // phrack, android.system.Os is only available from api level 21
/*
            if (android.os.Build.VERSION.SDK_INT == 21)
            {
                val AF_UNIX = 1
                mFileDescriptor = Os.socket(AF_UNIX, SOCKET_STREAM, 0)

                //mLocalServerSocket = new LocalServerSocket(mFileDescriptor) // dead end, no bind

                // LocalSocketServer::new
                val clazz = Class.forName('android.net.LocalSocketImpl')
                val ctors = clazz.declaredConstructors

                // Change the accessible property of the constructor.
                val ctor = ctors.get(1)
                ctor.accessible = true
                val impl = ctor.newInstance(mFileDescriptor)

                val bind = clazz.getDeclaredMethod('bind', #[ LocalSocketAddress ])
                bind.invoke(impl, #[ addr ])

                val listen = clazz.getDeclaredMethod('listen', #[ Integer.TYPE ])
                listen.invoke(impl, #[ BACK_LOG ])
            }else
            {
                // use own NDK JNI solution... fragmentation blues...
            }
*/
            // finally...
            // LocalSocketServer::new
            /*
            mLocalServerSocket =
                new LocalServerSocket(NodeJNI.createLocalSocket(location).createFileDescriptor)

            // The following will block, so no funky busy loops with sleep necessary
            mLocalSocketSender = mLocalServerSocket.accept
            */
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
    override void startSensor()
    {
        super.startSensor
        // TODO
        // Highlight actual working sensors, deactivate unsupported ones
        sepukuHandler.postDelayed([ stopSelf ], 300000)
    }
}

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

// TODO - NFC, Bluetooth, Camera, Sound IO, ...
// Design ideas: only turn on services, that the user actually wants to use at that time.
// Do not start stuff by default.