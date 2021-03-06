package net.i2p.router;

import java.io.*;
import java.util.*;
import net.i2p.*;
import net.i2p.app.*;
import net.i2p.update.*;
import net.i2p.crypto.*;

/**
 * Launches a router from a Mac App Bundle.  Uses Java 9 APIs.
 * Sets the following properties:
 * i2p.dir.base - this points to the (read-only) resources inside the bundle
 * mac.bundle.location - this points to the folder the bundle itself is located in.
 * router.pid - the pid of the java process.
 */
public class MacLauncher {

    /** this is totally undocumented */
    private static final String APP_PATH = "jpackage.app-path";

    public static void main(String[] args) throws Exception {
        String path = System.getProperty(APP_PATH,"unknown");
        File f = new File(path);
        File contents = f.getParentFile().getParentFile();
        File app = new File(contents, "app");
        File resources = new File(contents, "Resources");
        File bundleLocation = contents.getParentFile().getParentFile();

        System.setProperty("i2p.dir.base", resources.getAbsolutePath());
        System.setProperty("i2p.dir.lib", app.getAbsolutePath());
        System.setProperty("mac.bundle.location", bundleLocation.getAbsolutePath());
        System.setProperty("router.pid", String.valueOf(ProcessHandle.current().pid()));

        try {
            System.load(resources.getAbsolutePath() + "/libMacLauncher.jnilib");
            disableAppNap();
        } catch (Throwable bad) {
            // this is pretty bad - I2P is very slow if AppNap kicks in.
            // TODO: hook up to a console warning or similar.
            bad.printStackTrace(); 
        }


        Thread registrationThread = new Thread(REGISTER_UPP);
        registrationThread.setName("UPP Registration");
        registrationThread.setDaemon(true);
        registrationThread.start();

        RouterLaunch.main(args);
    }

    private static native void disableAppNap();

    private static final Runnable REGISTER_UPP = () -> {

        // first wait for the RouterContext to appear
        RouterContext ctx;
        while ((ctx = (RouterContext) RouterContext.getCurrentContext()) == null) {
            sleep(1000);
        }

        // then wait for ClientAppManager
        ClientAppManager cam;
        while ((cam = ctx.clientAppManager()) == null) {
            sleep(1000);
        }

        // then wait for the update manager
        UpdateManager um;
        while ((um = (UpdateManager) cam.getRegisteredApp(UpdateManager.APP_NAME)) == null) {
            sleep(1000);
        }

        var mup = new MacUpdateProcessor(ctx);        
        um.register(mup, UpdateType.ROUTER_SIGNED_SU3, SU3File.TYPE_DMG);
        um.register(mup, UpdateType.ROUTER_DEV_SU3, SU3File.TYPE_DMG);
    };

    private static void sleep(int millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException bad) {
            bad.printStackTrace();
            throw new RuntimeException(bad);
        }
    }
}
