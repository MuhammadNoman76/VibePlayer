using System.Text.Json;
using System.Text.Json.Serialization;

namespace VibePlayer.Core;

public sealed class ResumeEntry
{
    public long Ms { get; set; }
    public DateTime At { get; set; }
}

public sealed class SkipRange
{
    public long StartMs { get; set; }
    public long EndMs { get; set; }
}

public sealed class SkipEntry
{
    public List<SkipRange> Ranges { get; set; } = new();
    public DateTime At { get; set; }
}

/// <summary>What to do when a file is opened while a VibePlayer window is already open.</summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum InstanceMode { Ask, UseExisting, NewWindow }

/// <summary>
/// User preferences, recent files, resume positions and skip ranges, stored as JSON in %APPDATA%\VibePlayer.
/// Several player windows can run at once, so saving merges with what the others wrote.
/// </summary>
public sealed class AppSettings
{
    private const int MaxRecent = 12;
    private const int MaxResume = 400;
    private const int MaxSkips = 1000;

    public int Volume { get; set; } = 100;
    public bool Muted { get; set; }
    public bool Autoplay { get; set; } = true;
    public bool Loop { get; set; }
    public bool SkipEnabled { get; set; } = true;
    public bool ShowRemainingTime { get; set; }
    public bool ShowSkipNotice { get; set; }
    public int Brightness { get; set; } = 100;
    public InstanceMode InstanceMode { get; set; } = InstanceMode.Ask;
    public bool AlwaysOnTop { get; set; }

    public double? WindowLeft { get; set; }
    public double? WindowTop { get; set; }
    public double? WindowWidth { get; set; }
    public double? WindowHeight { get; set; }
    public bool WindowMaximized { get; set; }

    public List<string> Recent { get; set; } = new();
    public Dictionary<string, ResumeEntry> Resume { get; set; } = new();
    public Dictionary<string, SkipEntry> Skips { get; set; } = new();

    /// <summary>Snapshot of the file as last read/written - lets Save() tell our changes from other windows' changes.</summary>
    private AppSettings? _baseline;

    public static string DataDirectory =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "VibePlayer");

    private static string FilePath => Path.Combine(DataDirectory, "settings.json");

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static AppSettings Load()
    {
        var settings = WithFileLock(ReadFile) ?? new AppSettings();
        settings.Normalize();
        settings._baseline = settings.Clone();
        return settings;
    }

    public void Save()
    {
        try
        {
            WithFileLock(() =>
            {
                var disk = ReadFile();
                if (disk != null && _baseline != null)
                {
                    disk.Normalize();
                    MergeFrom(disk, _baseline);
                }
                Directory.CreateDirectory(DataDirectory);
                var tmp = FilePath + ".tmp";
                File.WriteAllText(tmp, JsonSerializer.Serialize(this, JsonOptions));
                File.Move(tmp, FilePath, overwrite: true);
                _baseline = Clone();
                return true;
            });
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Save settings");
        }
    }

    /// <summary>3-way merge: keep what this window changed, take everything else from disk.</summary>
    private void MergeFrom(AppSettings disk, AppSettings baseline)
    {
        T Pick<T>(T mine, T theirs, T original) => EqualityComparer<T>.Default.Equals(mine, original) ? theirs : mine;

        Volume = Pick(Volume, disk.Volume, baseline.Volume);
        Muted = Pick(Muted, disk.Muted, baseline.Muted);
        Autoplay = Pick(Autoplay, disk.Autoplay, baseline.Autoplay);
        Loop = Pick(Loop, disk.Loop, baseline.Loop);
        SkipEnabled = Pick(SkipEnabled, disk.SkipEnabled, baseline.SkipEnabled);
        ShowRemainingTime = Pick(ShowRemainingTime, disk.ShowRemainingTime, baseline.ShowRemainingTime);
        ShowSkipNotice = Pick(ShowSkipNotice, disk.ShowSkipNotice, baseline.ShowSkipNotice);
        Brightness = Pick(Brightness, disk.Brightness, baseline.Brightness);
        InstanceMode = Pick(InstanceMode, disk.InstanceMode, baseline.InstanceMode);
        AlwaysOnTop = Pick(AlwaysOnTop, disk.AlwaysOnTop, baseline.AlwaysOnTop);

        // Recent: ours first, then theirs - minus anything we removed (e.g. "Clear recent").
        var removed = baseline.Recent.Except(Recent, StringComparer.OrdinalIgnoreCase).ToHashSet(StringComparer.OrdinalIgnoreCase);
        Recent = Recent.Concat(disk.Recent.Where(r => !removed.Contains(r)))
            .Distinct(StringComparer.OrdinalIgnoreCase).Take(MaxRecent).ToList();

        // Per-file data: newest entry wins.
        foreach (var (key, theirs) in disk.Resume)
            if (!Resume.TryGetValue(key, out var mine) || theirs.At > mine.At) Resume[key] = theirs;
        foreach (var (key, theirs) in disk.Skips)
            if (!Skips.TryGetValue(key, out var mine) || theirs.At > mine.At) Skips[key] = theirs;
        Trim();
    }

    private static AppSettings? ReadFile()
    {
        try
        {
            return File.Exists(FilePath)
                ? JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath), JsonOptions)
                : null;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Read settings");
            return null;
        }
    }

    private static T? WithFileLock<T>(Func<T?> action)
    {
        using var mutex = new Mutex(false, @"Local\VibePlayer-settings-" + Environment.UserName);
        var owned = false;
        try
        {
            try { owned = mutex.WaitOne(TimeSpan.FromSeconds(3)); }
            catch (AbandonedMutexException) { owned = true; }
            return action();
        }
        finally
        {
            if (owned) mutex.ReleaseMutex();
        }
    }

    private void Normalize()
    {
        Resume = new Dictionary<string, ResumeEntry>(Resume ?? new(), StringComparer.OrdinalIgnoreCase);
        Skips = new Dictionary<string, SkipEntry>(Skips ?? new(), StringComparer.OrdinalIgnoreCase);
        Recent ??= new();
        Volume = Math.Clamp(Volume, 0, 200);
        Brightness = Math.Clamp(Brightness, 0, 200);
    }

    private AppSettings Clone()
    {
        var copy = JsonSerializer.Deserialize<AppSettings>(JsonSerializer.Serialize(this, JsonOptions), JsonOptions)!;
        copy.Normalize();
        return copy;
    }

    private void Trim()
    {
        if (Resume.Count > MaxResume)
            foreach (var old in Resume.OrderBy(kv => kv.Value.At).Take(Resume.Count - MaxResume).Select(kv => kv.Key).ToList())
                Resume.Remove(old);
        if (Skips.Count > MaxSkips)
            foreach (var old in Skips.OrderBy(kv => kv.Value.At).Take(Skips.Count - MaxSkips).Select(kv => kv.Key).ToList())
                Skips.Remove(old);
    }

    public void AddRecent(string source)
    {
        Recent.RemoveAll(r => string.Equals(r, source, StringComparison.OrdinalIgnoreCase));
        Recent.Insert(0, source);
        if (Recent.Count > MaxRecent) Recent.RemoveRange(MaxRecent, Recent.Count - MaxRecent);
    }

    // A position of 0 is kept (not removed) so that other windows' merges see it as the newest value.
    public long GetResume(string source) =>
        Resume.TryGetValue(source, out var entry) ? entry.Ms : 0;

    public void SetResume(string source, long ms)
    {
        if (ms <= 0 && !Resume.ContainsKey(source)) return;
        Resume[source] = new ResumeEntry { Ms = Math.Max(0, ms), At = DateTime.UtcNow };
        Trim();
    }

    public List<SkipRange> GetSkips(string source) =>
        Skips.TryGetValue(source, out var entry) ? entry.Ranges : new List<SkipRange>();

    public void SetSkips(string source, List<SkipRange> ranges)
    {
        Skips[source] = new SkipEntry
        {
            Ranges = ranges.OrderBy(r => r.StartMs).ToList(),
            At = DateTime.UtcNow,
        };
        Trim();
    }
}
