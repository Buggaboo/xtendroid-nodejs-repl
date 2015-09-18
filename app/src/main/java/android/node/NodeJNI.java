package android.node;


/**
 * Created by jasm on 1/22/15.
 */
public class NodeJNI {

    static {
        System.loadLibrary("node");
    }

    public static native int start(int argc, String[] argv);
    public static native int createLocalSocket(String where); // int socket(AF_LOCAL, SOCKET_STREAM, 0);

}
