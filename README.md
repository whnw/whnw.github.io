# whnw.github.io 文件站

公开文件统一放在 `content/`，其目录前缀不会出现在发布 URL 中。例如
`content/config/nvim/init.lua` 发布为 `/config/nvim/init.lua`。

## 更新内容

将文件放入 `content/` 后，按普通 Git 流程提交即可：

```sh
git add content
git commit -m "update files"
git push
```

推送到 `main` 后，GitHub Actions 会运行测试、生成 `_site/` 并部署 Pages。不要提交
`_site/` 或 Markdown 派生的 HTML；Markdown 原文件与自动生成的阅读页面会同时发布。

首次启用时，请在仓库 **Settings → Pages → Build and deployment → Source** 中选择
**GitHub Actions**。

## 本地检查

需要 Python 3 和 pandoc：

```sh
python3 -m unittest discover -s tests -v
python3 build.py
python3 -m http.server --directory _site 8000
```

然后访问 <http://localhost:8000>。浏览器下载目录功能使用仓库内固定版本的
JSZip 3.10.1，不依赖 CDN。

