// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// System Operating Room - Main Entry Point
// A comprehensive system maintenance and operations toolkit

module main;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import std.datetime;
import std.getopt;

// Configuration
enum REPOS_DIR = "/var/home/hyper/repos";
enum HOME_DIR = "/var/home/hyper";

void main(string[] args)
{
    if (args.length < 2)
    {
        printUsage();
        return;
    }

    string command = args[1];
    string[] subArgs = args.length > 2 ? args[2 .. $] : [];

    switch (command)
    {
        case "optimize":
            systemOptimize(subArgs);
            break;
        case "cleanup":
            systemCleanup(subArgs);
            break;
        case "sync":
            syncRepos(subArgs);
            break;
        case "check":
            checkRepos(subArgs);
            break;
        case "analyze":
            analyzeWorkflows(subArgs);
            break;
        case "pages":
            checkPagesStatus(subArgs);
            break;
        case "help":
            printUsage();
            break;
        default:
            writefln("Unknown command: %s", command);
            printUsage();
    }
}

void printUsage()
{
    writeln("System Operating Room - System Maintenance Toolkit");
    writeln("");
    writeln("Usage: sor <command> [options]");
    writeln("");
    writeln("Commands:");
    writeln("  optimize     Run system optimization (firewall, journal, services)");
    writeln("  cleanup      Clean caches and temporary files");
    writeln("  sync         Sync all git repositories");
    writeln("  check        Check repositories for uncommitted changes");
    writeln("  analyze      Analyze GitHub workflow failures");
    writeln("  pages        Check GitHub Pages status across repos");
    writeln("  help         Show this help message");
    writeln("");
    writeln("Examples:");
    writeln("  sor optimize --dry-run");
    writeln("  sor cleanup --all");
    writeln("  sor sync --parallel");
    writeln("  sor analyze --workflow=codeql");
}

// =============================================================================
// System Optimization
// =============================================================================

void systemOptimize(string[] args)
{
    bool dryRun = false;
    bool skipNvidia = false;
    bool skipFirewall = false;

    getopt(args,
        "dry-run", &dryRun,
        "skip-nvidia", &skipNvidia,
        "skip-firewall", &skipFirewall
    );

    writeln("=== System Optimization ===");
    writeln("");

    if (!skipNvidia)
    {
        writeln("[1/5] Configuring NVIDIA driver (blacklisting nouveau)...");
        if (!dryRun)
        {
            auto result = executeShell("rpm-ostree kargs --append=modprobe.blacklist=nouveau --append=rd.driver.blacklist=nouveau 2>&1");
            if (result.status == 0)
                writeln("✓ Nouveau blacklisted");
            else
                writefln("⚠ Failed: %s", result.output);
        }
        else
            writeln("  [dry-run] Would blacklist nouveau");
    }

    if (!skipFirewall)
    {
        writeln("[2/5] Configuring firewall...");
        if (!dryRun)
        {
            // Tighten firewall - only allow necessary ports
            string[] cmds = [
                "firewall-cmd --permanent --add-port=22000/tcp",   // Syncthing
                "firewall-cmd --permanent --add-port=22000/udp",   // Syncthing discovery
                "firewall-cmd --permanent --add-port=21027/udp",   // Syncthing local
                "firewall-cmd --permanent --add-port=1716/tcp",    // KDE Connect
                "firewall-cmd --permanent --add-port=1716/udp",    // KDE Connect
                "firewall-cmd --reload"
            ];
            foreach (cmd; cmds)
            {
                executeShell(cmd ~ " 2>/dev/null");
            }
            writeln("✓ Firewall configured (Syncthing + KDE Connect)");
        }
        else
            writeln("  [dry-run] Would configure firewall ports");
    }

    writeln("[3/5] Vacuuming journal logs...");
    if (!dryRun)
    {
        auto result = executeShell("sudo journalctl --vacuum-size=500M 2>&1");
        writeln("✓ Journal vacuumed to 500MB");
    }
    else
        writeln("  [dry-run] Would vacuum journal to 500MB");

    writeln("[4/5] Disabling unnecessary services...");
    if (!dryRun)
    {
        executeShell("systemctl disable --now ModemManager 2>/dev/null");
        executeShell("systemctl mask qemu-guest-agent 2>/dev/null");
        writeln("✓ ModemManager disabled, qemu-guest-agent masked");
    }
    else
        writeln("  [dry-run] Would disable ModemManager and mask qemu-guest-agent");

    writeln("[5/5] Configuring network (BBR congestion control)...");
    if (!dryRun)
    {
        string sysctlConfig = `# BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
`;
        std.file.write("/tmp/99-network-performance.conf", sysctlConfig);
        executeShell("sudo cp /tmp/99-network-performance.conf /etc/sysctl.d/ && sudo sysctl -p /etc/sysctl.d/99-network-performance.conf 2>&1");
        writeln("✓ BBR and network buffers configured");
    }
    else
        writeln("  [dry-run] Would configure BBR congestion control");

    writeln("");
    writeln("=== Optimization Complete ===");
    if (!dryRun)
        writeln("Note: Reboot required for NVIDIA changes to take effect");
}

// =============================================================================
// System Cleanup
// =============================================================================

void systemCleanup(string[] args)
{
    bool all = false;
    bool dryRun = false;

    getopt(args,
        "all", &all,
        "dry-run", &dryRun
    );

    writeln("=== System Cleanup ===");
    writeln("");

    struct CleanupTarget
    {
        string name;
        string path;
        string priority;
    }

    CleanupTarget[] targets = [
        CleanupTarget("debuginfod cache", HOME_DIR ~ "/.cache/debuginfod_client", "HIGH"),
        CleanupTarget("npm cache", HOME_DIR ~ "/.npm", "MEDIUM"),
        CleanupTarget("bun cache", HOME_DIR ~ "/.bun", "MEDIUM"),
        CleanupTarget("Edge Dev cache", HOME_DIR ~ "/.var/app/com.microsoft.EdgeDev/cache", "MEDIUM"),
        CleanupTarget("partial downloads", HOME_DIR ~ "/Downloads/*.part", "LOW"),
    ];

    ulong totalFreed = 0;

    foreach (target; targets)
    {
        if (std.file.exists(target.path) || target.path.canFind("*"))
        {
            ulong size = 0;
            if (!target.path.canFind("*"))
            {
                try
                {
                    size = dirSize(target.path);
                }
                catch (Exception e)
                {
                    size = 0;
                }
            }

            writefln("[%s] %s: %s", target.priority, target.name, formatSize(size));

            if (!dryRun)
            {
                if (target.path.canFind("*"))
                {
                    executeShell("rm -f " ~ target.path ~ " 2>/dev/null");
                }
                else
                {
                    executeShell("rm -rf " ~ target.path ~ " 2>/dev/null");
                }
                writeln("  ✓ Cleaned");
                totalFreed += size;
            }
            else
            {
                writeln("  [dry-run] Would clean");
            }
        }
    }

    writeln("");
    writefln("Total freed: %s", formatSize(totalFreed));
    writeln("");
    writeln("Note: Run with sudo for journal/coredump cleanup:");
    writeln("  sudo journalctl --vacuum-size=500M");
    writeln("  sudo rm -rf /var/lib/systemd/coredump/*");
}

ulong dirSize(string path)
{
    ulong size = 0;
    try
    {
        foreach (entry; dirEntries(path, SpanMode.depth))
        {
            if (entry.isFile)
                size += entry.size;
        }
    }
    catch (Exception e)
    {
        // Ignore permission errors
    }
    return size;
}

string formatSize(ulong bytes)
{
    if (bytes >= 1_073_741_824)
        return format("%.1f GB", bytes / 1_073_741_824.0);
    else if (bytes >= 1_048_576)
        return format("%.1f MB", bytes / 1_048_576.0);
    else if (bytes >= 1024)
        return format("%.1f KB", bytes / 1024.0);
    else
        return format("%d B", bytes);
}

// =============================================================================
// Repository Sync
// =============================================================================

void syncRepos(string[] args)
{
    bool parallel = false;
    bool dryRun = false;

    getopt(args,
        "parallel", &parallel,
        "dry-run", &dryRun
    );

    writeln("=== Syncing Repositories ===");
    writeln("");

    string[] repos;
    foreach (entry; dirEntries(REPOS_DIR, SpanMode.shallow))
    {
        if (entry.isDir)
        {
            string gitPath = buildPath(entry.name, ".git");
            if (std.file.exists(gitPath))
            {
                repos ~= entry.name;
            }
        }
    }

    writefln("Found %d repositories", repos.length);
    writeln("");

    int synced = 0;
    int failed = 0;

    foreach (repo; repos)
    {
        string repoName = baseName(repo);
        write(repoName ~ ": ");
        stdout.flush();

        if (dryRun)
        {
            writeln("[dry-run]");
            continue;
        }

        auto fetchResult = executeShell("cd " ~ repo ~ " && git fetch --all -q 2>&1");
        auto pullResult = executeShell("cd " ~ repo ~ " && git pull -q 2>&1");

        if (fetchResult.status == 0 && pullResult.status == 0)
        {
            writeln("✓");
            synced++;
        }
        else
        {
            writeln("⚠ (has local changes or conflicts)");
            failed++;
        }
    }

    writeln("");
    writefln("Synced: %d, Failed: %d", synced, failed);
}

// =============================================================================
// Check Repositories for Changes
// =============================================================================

void checkRepos(string[] args)
{
    writeln("=== Checking Repositories for Uncommitted Changes ===");
    writeln("");

    int withChanges = 0;

    foreach (entry; dirEntries(REPOS_DIR, SpanMode.shallow))
    {
        if (entry.isDir)
        {
            string gitPath = buildPath(entry.name, ".git");
            if (std.file.exists(gitPath))
            {
                auto result = executeShell("cd " ~ entry.name ~ " && git status --porcelain 2>/dev/null");
                if (result.output.strip().length > 0)
                {
                    writefln("=== %s ===", baseName(entry.name));
                    auto shortResult = executeShell("cd " ~ entry.name ~ " && git status --short 2>/dev/null | head -8");
                    writeln(shortResult.output);
                    withChanges++;
                }
            }
        }
    }

    if (withChanges == 0)
        writeln("All repositories are clean!");
    else
        writefln("\n%d repositories have uncommitted changes", withChanges);
}

// =============================================================================
// Analyze GitHub Workflows
// =============================================================================

void analyzeWorkflows(string[] args)
{
    string workflow = "";

    getopt(args,
        "workflow", &workflow
    );

    writeln("=== Analyzing GitHub Workflow Failures ===");
    writeln("");

    string[] workflowTypes = [
        "Workflow Security Linter",
        "Code Quality",
        "CodeQL Security Analysis",
        "OpenSSF Scorecard Enforcer",
        "Mirror to Git Forges",
        "GitHub Pages"
    ];

    if (workflow.length > 0)
    {
        workflowTypes = workflowTypes.filter!(w => w.toLower().canFind(workflow.toLower())).array;
    }

    auto reposResult = executeShell(`gh repo list hyperpolymath --limit 100 --json name -q ".[].name" 2>/dev/null`);
    string[] repos = reposResult.output.strip().split("\n");

    foreach (wfType; workflowTypes)
    {
        writefln("=== %s FAILURES ===", wfType.toUpper());

        foreach (repo; repos)
        {
            string jqFilter = format(`[.[] | select(.name == "%s")] | length`, wfType);
            string cmd = format(`gh run list --repo "hyperpolymath/%s" --status failure --limit 10 --json name -q '%s' 2>/dev/null`, repo, jqFilter);
            auto result = executeShell(cmd);

            int count = 0;
            try
            {
                count = result.output.strip().to!int;
            }
            catch (Exception e)
            {
                count = 0;
            }

            if (count > 0)
                writefln("  %s: %d", repo, count);
        }
        writeln("");
    }
}

// =============================================================================
// Check GitHub Pages Status
// =============================================================================

void checkPagesStatus(string[] args)
{
    writeln("=== Checking GitHub Pages Status ===");
    writeln("");

    auto reposResult = executeShell(`gh repo list hyperpolymath --limit 100 --json name -q ".[].name" 2>/dev/null`);
    string[] repos = reposResult.output.strip().split("\n");

    writeln("Repos with Pages workflow but Pages NOT enabled:");
    writeln("");

    foreach (repo; repos)
    {
        // Check if Pages workflow exists
        auto wfCheck = executeShell(format(`gh api "repos/hyperpolymath/%s/contents/.github/workflows/jekyll-gh-pages.yml" 2>/dev/null`, repo));

        if (wfCheck.status == 0)
        {
            // Check if Pages is enabled
            auto pagesCheck = executeShell(format(`gh api "repos/hyperpolymath/%s/pages" 2>/dev/null`, repo));

            if (pagesCheck.status != 0)
            {
                writefln("  %s - has workflow but Pages NOT enabled", repo);
            }
        }
    }
}
