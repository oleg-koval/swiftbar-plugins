import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const nextVersion = process.argv[2];

if (!nextVersion) {
  console.error("Expected semantic-release to pass the next version.");
  process.exit(1);
}

const rootDir = process.cwd();
const pluginPath = path.join(rootDir, "system-monitor.5s.sh");
const swiftbarPluginPath = path.join(rootDir, "swiftbar", "system-monitor.5s.sh");
const pluginSource = await readFile(pluginPath, "utf8");

const updatedSource = pluginSource
  .replace(
    /^# <xbar\.version>v[^<]+<\/xbar\.version>$/m,
    `# <xbar.version>v${nextVersion}</xbar.version>`
  )
  .replace(/^PLUGIN_VERSION="[^"]+"$/m, `PLUGIN_VERSION="${nextVersion}"`);

if (updatedSource === pluginSource) {
  console.error("Version sync did not update the plugin metadata.");
  process.exit(1);
}

await writeFile(pluginPath, updatedSource);
await writeFile(swiftbarPluginPath, updatedSource);
