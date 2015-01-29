package nl.sison.android.nodejs.repl

import android.support.v4.app.Fragment
import android.os.Handler
import android.os.Bundle

import org.xtendroid.annotations.AndroidFragment
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


@AndroidFragment(R.layout.fragment_repl) class ReplFragment extends Fragment
{
    val mHandler = new Handler()

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

    @OnCreate
    def init() {
        readStdout()
        out = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(inFile)))
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
                    mHandler.post([
                        textView.text = str
                    ])
                }
                in.close()
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

    // don't close and flush, until you're realy done
    override onDestroy()
    {
        out.flush()
        out.close()
    }

}