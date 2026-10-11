namespace VibePlayer.Core;

internal static class Log
{
    private static readonly object Gate = new();

    public static void Error(Exception? ex, string? context = null)
    {
        if (ex == null) return;
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(AppSettings.DataDirectory);
                var file = Path.Combine(AppSettings.DataDirectory, "error.log");
                if (File.Exists(file) && new FileInfo(file).Length > 1_000_000) File.Delete(file);
                File.AppendAllText(file, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {context}{Environment.NewLine}{ex}{Environment.NewLine}{Environment.NewLine}");
            }
        }
        catch
        {
            // Logging must never take the player down.
        }
    }
}
