package nl.sison.android.nodejs.repl

import nl.sison.android.nodejs.R
import android.support.v7.app.ActionBarActivity
import android.support.v4.app.Fragment
import android.content.res.Configuration
import android.widget.ArrayAdapter
import android.view.Menu
import android.view.MenuItem

import org.xtendroid.app.AndroidActivity
import org.xtendroid.app.OnCreate

import nl.sison.android.nodejs.repl.ReplFragment
import android.content.Intent
import android.os.Bundle

import android.os.Handler
import android.os.Looper

// Since this is deprecated: import nl.sison.android.nodejs.services.*
// bash command to generate it: grep sensors ./src/main/AndroidManifest.xml | sed 's/.*sensors.\(.*\)".*/import nl.sison.android.nodejs.sensors.\1/'

// The wildcard is deprecated, hence the noise
//import nl.sison.android.nodejs.sensors.*

import nl.sison.android.nodejs.sensors.SensorService
import nl.sison.android.nodejs.sensors.AccelerometerService
import nl.sison.android.nodejs.sensors.AmbientTemperatureService
import nl.sison.android.nodejs.sensors.GameRotationVectorService
import nl.sison.android.nodejs.sensors.GeoMagneticRotationVectorService
import nl.sison.android.nodejs.sensors.GravityService
import nl.sison.android.nodejs.sensors.GyroscopeService
import nl.sison.android.nodejs.sensors.GyroscopeUncalibratedService
import nl.sison.android.nodejs.sensors.HeartRateService
import nl.sison.android.nodejs.sensors.LightService
import nl.sison.android.nodejs.sensors.LinearAccelerationService
import nl.sison.android.nodejs.sensors.MagneticFieldService
import nl.sison.android.nodejs.sensors.MagneticFieldUncalibratedService
import nl.sison.android.nodejs.sensors.PressureService
import nl.sison.android.nodejs.sensors.ProximityService
import nl.sison.android.nodejs.sensors.RelativeHumidityService
import nl.sison.android.nodejs.sensors.RotationVectorService
import nl.sison.android.nodejs.sensors.SignificantMotionService
import nl.sison.android.nodejs.sensors.StepCounterService
import nl.sison.android.nodejs.sensors.StepDetectorService

// TODO determine that 'settings' magic keyword is broken
// See [Settings](https://github.com/tobykurien/Xtendroid/blob/master/Xtendroid/docs/index.md)
import static extension nl.sison.android.nodejs.repl.Settings.*
import static extension android.preference.PreferenceManager.* // broken on android studio
import android.preference.PreferenceManager

import android.content.Context

import android.content.SharedPreferences

import java.util.List
import android.preference.PreferenceActivity
import android.preference.PreferenceFragment

import android.util.Log
import org.xtendroid.annotations.AddLogTag

import static extension gr.uoa.di.android.helpers.Net.*


/**
 * TODO add ip address on drawer
 *
 * TODO if drawerLearned === false then set sane defaults on sensor classes, activate only stuff
 * that are actually physically/feasibly available on the specific device model.
 */
@AddLogTag
@AndroidActivity(R.layout.activity_main_blacktoolbar) class MainActivity extends ActionBarActivity {

    ReplFragment fragment

    @OnCreate
    def init() {
        setupToolbar
        setupDrawerLayout
        setupFragment // place a fragment already
        startServices
    }

    /** java doesn't have const type const, so this datastructure is still modifiable at runtime */
    static public val classes = #[
        AccelerometerService,
        AmbientTemperatureService,
        GameRotationVectorService,
        GeoMagneticRotationVectorService,
        GravityService,
        GyroscopeService,
        GyroscopeUncalibratedService,
        HeartRateService,
        LightService,
        LinearAccelerationService,
        MagneticFieldService,
        MagneticFieldUncalibratedService,
        PressureService,
        ProximityService,
        RelativeHumidityService,
        RotationVectorService,
        SignificantMotionService,
        StepCounterService,
        StepDetectorService
    ]

    // bash command to generate th startService method calls
    // grep sensors ./src/main/AndroidManifest.xml | sed 's/.*sensors.\(.*\)".*/startService(new Intent(this, \1))/'
    Handler handler = new Handler
    def startServices ()
    {
        val context = applicationContext as Context
        // The following statement should be:
        // val prefs = context.defaultSharedPreferences
        // but try arguing with a pre-alpha Xtend IDE plugins...
        // TODO complain, then wait for the fix :P
        // The weird thing is that SensorServicePreferenceActivity, does it properly
        val SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context)

        // TODO run the first time the app starts
        startService(new Intent(this, SensorService))

        // just run it on the ui thread, sequentially, controlled, 3s bursts
        (0..(classes.length-1)).forEach[ i |
            if (prefs.getBoolean(classes.get(i).simpleName.replace('Service','').snakeCase, false))
            {
                handler.postDelayed([
                    MainActivity.this.startService(new Intent(MainActivity.this, classes.get(i)))
                ],  i * 3000)
            }else
            {
                // kill immediately, no delay
                MainActivity.this.stopService(new Intent(MainActivity.this, classes.get(i)))
            }
        ]
    }

    def setupFragment()
    {
         // TODO inject text instead of whole fragment
         val tx = supportFragmentManager.beginTransaction
         fragment = new ReplFragment
         tx.add(R.id.container, fragment as Fragment).commit
    }
    
    MyActionBarDrawerToggle actionBarDrawerToggle
    
    def setupDrawerLayout()
    {
        val listView = drawerListView
    
        val String[] arrayOfWords = #["Sensors", "About"]
        listView.adapter = new ArrayAdapter<String>(this, R.layout.drawer_list_item, arrayOfWords)
        var android.widget.AdapterView.OnItemClickListener listener = [ parent, view, position, id |
            if ('Sensors'.equals(arrayOfWords.get(position)))
            {
                startActivity(new Intent(applicationContext, SensorServicePreferenceActivity))
            }
        ] // TODO add injectable examples

        listView.onItemClickListener = listener
    
        val drawer = drawerLayout
    
        actionBarDrawerToggle = new MyActionBarDrawerToggle(this, drawer, toolbar)
    
        // This following line actually reveals the hamburger
        drawer.post[ actionBarDrawerToggle.syncState() ]
    
        drawer.drawerListener = actionBarDrawerToggle
    }
    
    override boolean onCreateOptionsMenu(Menu menu)
    {
        val inflater = menuInflater
        inflater.inflate(R.menu.main, menu)
        return super.onCreateOptionsMenu(menu)
    }
    
    def setupToolbar()
    {
        supportActionBar = toolbar
        val actionBar = supportActionBar
        actionBar.displayHomeAsUpEnabled = true
    }
    
    /**
     * TODO destroy Activity when no fragment is on the fragment stack
     */
    override onBackPressed() {
        val listView = drawerListView
        if (drawerLayout.isDrawerOpen(listView))
            drawerLayout.closeDrawer(listView)
        else
            super.onBackPressed()
    }
    
    override boolean onOptionsItemSelected(MenuItem item) {

        if (#[R.id.run, R.id.save, R.id.share, R.id.clear].contains(item.itemId))
        {
            if (fragment != null)
            {
                return fragment.onOptionsItemSelected(item)
            }
        }

        // TODO flesh out
        return super.onOptionsItemSelected(item)
    }
    
    /**
     * Invariant to changes in orientation
     */
    override onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig)
        actionBarDrawerToggle.onConfigurationChanged(newConfig)
    }
}

@AddLogTag
class SensorServicePreferenceActivity extends PreferenceActivity
{
    var SharedPreferences prefs
    var SharedPreferences$OnSharedPreferenceChangeListener prefsListener

    var classes = MainActivity.classes

    override void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState)

        prefs  = defaultSharedPreferences

        prefsListener = [ ps, key |
            val type = classes.findFirst[ c | c.simpleName.replace('Service','').snakeCase.equals(key) ]
            if (ps.getBoolean(key, false))
            {
                startService(new Intent(this, type))
            }else
            {
                stopService(new Intent(this, type))
            }
        ]
        // register prefs listener
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)

        addPreferencesFromResource(R.xml.preference_sensors)

    }

    override void onDestroy()
    {
        super.onDestroy
        prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
    }
}