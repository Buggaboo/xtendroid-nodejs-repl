package nl.sison.android.nodejs.repl

import android.support.v4.app.Fragment
import android.os.Bundle

import org.xtendroid.annotations.AndroidFragment
import org.xtendroid.annotations.AddLogTag
import org.xtendroid.app.OnCreate
import nl.sison.android.nodejs.repl.NodeJNI

//import static extension org.xtendroid.utils.AlertUtils.*
import static extension nl.sison.android.nodejs.repl.Settings.*
import org.xtendroid.annotations.BundleProperty

import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.FileReader
import java.io.IOException
import java.io.OutputStreamWriter

import android.util.Log

/**
 * TODO deprecate, then remove all stdio redirection code, in two commits
 * TODO make unix local socket work first
 */

@AddLogTag
@AndroidFragment(R.layout.fragment_repl) class ReplFragment extends Fragment
{
    public new ()
    {
        // TODO put this in the Xtendroid default ctor
        arguments = new Bundle()
    }

    @BundleProperty
    String outFile

    @BundleProperty
    String inFile

    BufferedWriter out

    override onResume() {
        super.onResume()
//        readStdout()
//        out = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(inFile)))
    }

    // perpetually read from stdout to TextView, run once
    public def readStdout()
    {
        new Thread([
            var BufferedReader in = null
            try {
                in = new BufferedReader(new FileReader(outFile))
                while (in.ready())
                {
                    val str = in.readLine()
                    Log.d(TAG, String.format("Redirected Stdout: %s", str))
//                    mHandler.post([
//                        textView.text = str
//                    ])
                }
                in.close()
                Log.d(TAG, "Redirected Stdout closed")
            }catch (FileNotFoundException e)
            {
                e.printStackTrace()
            }catch (IOException e)
            {
                e.printStackTrace()
            }
        ]).start()
    }

    // write to stdin from EditText
    public def writeToStdin(String content)
    {
        new Thread([
            try {
                out.write(content.toCharArray(), 0, content.toCharArray().length);
            }catch (FileNotFoundException e)
            {
                e.printStackTrace()
            }catch (IOException e)
            {
                e.printStackTrace()
            }
        ]).start()
    }

    // don't close and flush, until you're really done
    override onPause()
    {
        super.onPause()
//        out.flush()
//        out.close()
    }

}