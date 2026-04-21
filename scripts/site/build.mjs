import { cp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const rootDir = process.cwd();
const siteDir = path.join(rootDir, "site");
const distDir = path.join(rootDir, "dist");
const pluginPath = path.join(rootDir, "system-monitor.5s.sh");

const repoUrl = "https://github.com/oleg-koval/swiftbar-plugins";
const rawPluginUrl =
  "https://raw.githubusercontent.com/oleg-koval/swiftbar-plugins/main/system-monitor.5s.sh";
const releasesUrl = `${repoUrl}/releases`;
const siteUrl = "https://oleg-koval.github.io/swiftbar-plugins/";

function extractVersion(source) {
  const match = source.match(/^PLUGIN_VERSION="([^"]+)"$/m);

  if (!match) {
    throw new Error("Could not read PLUGIN_VERSION from system-monitor.5s.sh");
  }

  return match[1];
}

async function replaceTokens(filePath, replacements) {
  const original = await readFile(filePath, "utf8");
  let updated = original;

  for (const [token, value] of Object.entries(replacements)) {
    updated = updated.replaceAll(token, value);
  }

  if (updated !== original) {
    await writeFile(filePath, updated);
  }
}

async function walk(dirPath) {
  const entries = await stat(dirPath);

  if (!entries.isDirectory()) {
    return [dirPath];
  }

  const childNames = await readdir(dirPath);
  const nested = await Promise.all(
    childNames.map((childName) => walk(path.join(dirPath, childName)))
  );

  return nested.flat();
}

await rm(distDir, { force: true, recursive: true });
await cp(siteDir, distDir, { recursive: true });
await cp(pluginPath, path.join(distDir, "system-monitor.5s.sh"));

const pluginSource = await readFile(pluginPath, "utf8");
const pluginVersion = extractVersion(pluginSource);
const replacements = {
  "{{PLUGIN_VERSION}}": pluginVersion,
  "{{REPO_URL}}": repoUrl,
  "{{RAW_PLUGIN_URL}}": rawPluginUrl,
  "{{RELEASES_URL}}": releasesUrl,
  "{{SITE_URL}}": siteUrl,
  "{{YEAR}}": String(new Date().getFullYear())
};

for (const filePath of await walk(distDir)) {
  if (/\.(html|css|js|json|svg|txt)$/u.test(filePath)) {
    await replaceTokens(filePath, replacements);
  }
}

await writeFile(
  path.join(distDir, "version.json"),
  `${JSON.stringify({ version: pluginVersion }, null, 2)}\n`
);
