package wpset;

import android.app.WallpaperManager;
import android.content.Context;
import android.os.Looper;
import java.io.FileInputStream;
import java.lang.reflect.Method;

/**
 * Define o wallpaper (home + lock) sem abrir nenhuma tela, via app_process.
 *
 * O WallpaperManagerService exige que o UID da chamada seja dono do pacote informado;
 * por isso o script scripts/set-wallpaper.ps1 roda este codigo como uid 1000 (system),
 * dono do pacote "android". Rodar como root puro falha em enforcePackageBelongsToUid.
 */
public class SetWallpaper {
    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.out.println("uso: SetWallpaper <arquivo>");
            return;
        }

        if (Looper.myLooper() == null) {
            Looper.prepareMainLooper();
        }

        Class<?> activityThread = Class.forName("android.app.ActivityThread");
        Object thread = activityThread.getMethod("systemMain").invoke(null);
        Context ctx = (Context) activityThread.getMethod("getSystemContext").invoke(thread);
        if (ctx == null) {
            System.out.println("FALHA: contexto do sistema indisponivel");
            return;
        }

        WallpaperManager wm = WallpaperManager.getInstance(ctx);
        FileInputStream in = new FileInputStream(args[0]);
        int id;
        try {
            id = wm.setStream(in, null, true, WallpaperManager.FLAG_SYSTEM | WallpaperManager.FLAG_LOCK);
        } finally {
            in.close();
        }
        System.out.println("OK wallpaperId=" + id
                + " minW=" + wm.getDesiredMinimumWidth()
                + " minH=" + wm.getDesiredMinimumHeight());
    }
}
