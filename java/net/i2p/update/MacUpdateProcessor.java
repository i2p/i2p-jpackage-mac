package net.i2p.update;

import net.i2p.router.*;
import net.i2p.util.*;
import net.i2p.crypto.*;

import java.io.*;
import java.util.concurrent.atomic.*;
import java.nio.file.*;

public class MacUpdateProcessor implements UpdatePostProcessor {

    private final RouterContext ctx;
    private final Log log;
    private final AtomicBoolean hook = new AtomicBoolean();

    private volatile String version;

    public MacUpdateProcessor(RouterContext ctx) {
        this.ctx = ctx;
        log = ctx.logManager().getLog(MacUpdateProcessor.class);
    }

    public String getVersion() {
        return version;
    }

    @Override
    public void updateDownloadedandVerified(UpdateType type, int fileType, String version, File file) throws IOException {
        log.info("Got an update to post-process");

        if (type != UpdateType.ROUTER_SIGNED_SU3 && type != UpdateType.ROUTER_DEV_SU3) {
            log.warn("Unsupported update type " + type);
            return;
        }

        if (fileType != SU3File.TYPE_DMG) {
            log.warn("Unsupported file type " + fileType);
            return;
        }

        // good to go

        // first check if working directory is fine
        var workDir = new File(ctx.getConfigDir(), "mac_updates");

        if (workDir.exists()) {
            if (workDir.isFile())
                throw new IOException(workDir + " exists but is a file, get it out of the way");
        } else
            workDir.mkdirs();
        

        var dmg = new File(workDir, "I2P-" + version + ".dmg");
        if (!FileUtil.copy(file,dmg,true,false))
            throw new IOException("Couldn't copy extracted update");

        this.version = version;
        
        if (!hook.compareAndSet(false,true)) {
            log.info("shutdown hook was already set");
            return;
        }

        try(InputStream scriptStream = MacUpdateProcessor.class.getClassLoader().getResourceAsStream("mac-update.sh")) {
            var scriptFile = new File(workDir,"mac-update.sh");
            Files.copy(scriptStream, scriptFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
            if (!scriptFile.setExecutable(true))
                throw new IOException("couldn't mark script file executable");
        }

        log.info("adding shutdown hook");
        ctx.addFinalShutdownTask(new MacUpdateProcess(ctx, this::getVersion));
        
    }
}
