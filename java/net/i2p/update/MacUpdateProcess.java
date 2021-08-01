package net.i2p.update;

import net.i2p.router.*;

import java.util.function.*;
import java.io.*;

class MacUpdateProcess implements Runnable {
    private final RouterContext ctx;
    private final Supplier<String> versionSupplier;

    MacUpdateProcess(RouterContext ctx, Supplier<String> versionSupplier) {
        this.ctx = ctx;
        this.versionSupplier = versionSupplier;
    }

    @Override
    public void run() {
        String version = versionSupplier.get();

        var workingDir = new File(ctx.getConfigDir(), "mac_updates");
        var logFile = new File(workingDir, "log-" + version + ".txt");

        var pb = new ProcessBuilder("./mac-update.sh");
        var env = pb.environment();
        env.put("I2P_PID", System.getProperty("router.pid"));
        env.put("I2P_VERSION", version);
        env.put("BUNDLE_HOME", System.getProperty("mac.bundle.location"));

        try {
            var process = pb.
                        directory(workingDir).
                        redirectErrorStream(true).
                        redirectOutput(logFile).
                        start();
        
            System.out.println("Started update process with PID:" + process.toHandle().pid());
        } catch (IOException bad) {
            bad.printStackTrace();
        }
    }
}
