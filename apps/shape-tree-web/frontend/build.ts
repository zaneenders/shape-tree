import { copyFileSync, readFileSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const packageRoot = resolve(import.meta.dir, "..");
const distDir = resolve(packageRoot, "dist");
const sampleFitSource = resolve(import.meta.dir, "app/sample.fit");
const wasmOutputsDir = resolve(
  import.meta.dir,
  ".build/plugins/PackageToJS/outputs",
);

const wasmProducts = ["Entry", "FitViewer", "ArticlesViewer", "FavoritesViewer"] as const;

await mkdir(distDir, { recursive: true });

copyFileSync(sampleFitSource, resolve(distDir, "sample.fit"));
console.log("copied app/sample.fit → dist/sample.fit");

for (const product of wasmProducts) {
  copyFileSync(
    resolve(wasmOutputsDir, product, `${product}.wasm`),
    resolve(distDir, `${product}.wasm`),
  );
  console.log(`copied ${product}.wasm → dist/${product}.wasm`);
}

async function buildBootstrap(
  entrypoint: string,
  outfile: string,
): Promise<void> {
  const result = await Bun.build({
    entrypoints: [resolve(import.meta.dir, entrypoint)],
    target: "browser",
    minify: true,
  });

  if (!result.success) {
    for (const log of result.logs) {
      console.error(log);
    }
    process.exit(1);
  }

  const [output] = result.outputs;
  if (!output) {
    console.error(`build produced no output for ${entrypoint}`);
    process.exit(1);
  }

  await Bun.write(resolve(distDir, outfile), output);
}

await buildBootstrap("app/entry-bootstrap.ts", "app.js");
await buildBootstrap("app/fit-viewer-bootstrap.ts", "fit-viewer-bootstrap.js");
await buildBootstrap(
  "app/articles-viewer-bootstrap.ts",
  "articles-viewer-bootstrap.js",
);
await buildBootstrap(
  "app/favorites-viewer-bootstrap.ts",
  "favorites-viewer-bootstrap.js",
);

const styles = readFileSync(resolve(import.meta.dir, "app/app.css"), "utf8");
await Bun.write(resolve(distDir, "app.css"), styles);
