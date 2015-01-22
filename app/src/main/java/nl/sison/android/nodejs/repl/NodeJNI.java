package nl.sison.android.nodejs.repl;

/**
 * Created by jasm on 1/22/15.
 */
public class NodeJNI {

    static {
        System.loadLibrary("node");
    }

    public static native int initStdio(String inputFile, String outputFile);

    public static native int start(int argc, String[] argv);
}