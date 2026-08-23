(() => {
  "use strict";
  const LIMIT = 100 * 1024 * 1024;
  const CONCURRENCY = 4;
  const buttons = document.querySelectorAll("[data-download-path]");
  const status = document.querySelector("#download-status");
  if (!buttons.length) return;

  const setStatus = text => { status.textContent = text; };
  const safeName = name => name.replace(/[\\/:*?"<>|]/g, "_") || "content";

  async function downloadDirectory(button) {
    button.disabled = true;
    try {
      setStatus("正在读取文件清单…");
      const manifestResponse = await fetch("/manifest.json", { cache: "no-cache" });
      if (!manifestResponse.ok) throw new Error(`读取清单失败（HTTP ${manifestResponse.status}）`);
      const manifest = await manifestResponse.json();
      const selected = button.dataset.downloadPath;
      const files = manifest.filter(file => !selected || file.path === selected || file.path.startsWith(selected + "/"));
      const total = files.reduce((sum, file) => sum + file.size, 0);
      if (!files.length) throw new Error("所选目录没有可下载文件");
      if (total > LIMIT && !window.confirm(`目录约 ${(total / 1048576).toFixed(1)} MiB，浏览器打包会占用较多内存并可能耗时较长。仍要继续吗？`)) {
        setStatus("已取消下载。"); return;
      }
      const zip = new JSZip();
      const controller = new AbortController();
      const rootName = safeName(selected ? selected.split("/").pop() : "content");
      let next = 0, completed = 0;
      async function worker() {
        while (next < files.length) {
          const file = files[next++];
          let response;
          try {
            response = await fetch(file.url, { signal: controller.signal });
            if (!response.ok) throw new Error(`下载失败：${file.path}（HTTP ${response.status}）`);
            const data = await response.arrayBuffer();
            if (data.byteLength !== file.size) throw new Error(`文件大小不符：${file.path}`);
            const relative = selected ? file.path.slice(selected.length + 1) : file.path;
            zip.file(`${rootName}/${relative}`, data);
          } catch (error) {
            controller.abort();
            throw error;
          }
          completed++;
          setStatus(`正在下载 ${completed}/${files.length}：${file.path}`);
        }
      }
      await Promise.all(Array.from({ length: Math.min(CONCURRENCY, files.length) }, worker));
      setStatus("文件下载完成，正在压缩 0%…");
      const blob = await zip.generateAsync({ type: "blob", compression: "DEFLATE", compressionOptions: { level: 6 } }, metadata => {
        setStatus(`文件下载完成，正在压缩 ${metadata.percent.toFixed(0)}%…`);
      });
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = `${rootName}.zip`;
      link.click();
      setTimeout(() => URL.revokeObjectURL(link.href), 60000);
      setStatus(`已生成 ${link.download}。`);
    } catch (error) {
      setStatus(`下载终止：${error.message}。未生成 ZIP。`);
    } finally {
      button.disabled = false;
    }
  }

  buttons.forEach(button => button.addEventListener("click", event => {
    event.preventDefault();
    event.stopPropagation();
    downloadDirectory(button);
  }));
})();
