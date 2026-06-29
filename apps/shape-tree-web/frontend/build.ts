import { copyFileSync, readFileSync, rmSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const packageRoot = resolve(import.meta.dir, "..");
const distDir = resolve(packageRoot, "dist");
const sampleFitSource = resolve(import.meta.dir, "app/sample.fit");
const wasmOutputsDir = resolve(
  import.meta.dir,
  ".build/plugins/PackageToJS/outputs",
);

await mkdir(distDir, { recursive: true });

copyFileSync(sampleFitSource, resolve(distDir, "sample.fit"));
console.log("copied app/sample.fit → dist/sample.fit");

const articleSource = resolve(import.meta.dir, "app/article.md");
copyFileSync(articleSource, resolve(distDir, "article.md"));
console.log("copied app/article.md → dist/article.md");

for (const product of ["Entry", "FitViewer", "ArticleViewer"] as const) {
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
  "app/article-viewer-bootstrap.ts",
  "article-viewer-bootstrap.js",
);

const styles = readFileSync(resolve(import.meta.dir, "app/app.css"), "utf8");
await Bun.write(resolve(distDir, "app.css"), styles);
