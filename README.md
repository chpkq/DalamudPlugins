# Personal Dalamud Plugin Repository

这是一个用于分发个人 Dalamud 插件的自定义仓库。根目录的 [`repo.json`](repo.json) 是 Dalamud 实际读取的索引文件；它可以包含多个插件。

## 首次发布

1. 在 GitHub 新建一个**公开**仓库，并将本目录推送到 `main` 分支。
2. 在 Dalamud 的 **Settings → Experimental → Custom Plugin Repositories** 中添加：

   ```text
   https://raw.githubusercontent.com/chpkq/DalamudPlugins/main/repo.json
   ```

3. 保存后打开 Plugin Installer。现在仓库是有效的，但尚未包含插件，因此列表为空。

> 也可以用 GitHub Pages 托管同一个文件，但 `raw.githubusercontent.com` 更简单，不需要额外部署。仓库和 ZIP 下载地址必须能被客户端匿名 HTTPS `GET` 访问；私有仓库或需要登录的地址不能使用。

## 添加一个插件

每个插件先在自己的源码仓库中构建并发布 ZIP。ZIP 的根目录必须包含插件 DLL 与由 `Dalamud.NET.Sdk`/`DalamudPackager` 生成的 manifest。可从 [Dalamud SamplePlugin](https://github.com/goatcorp/SamplePlugin) 开始。

随后：

1. 复制 [`plugins/PersonalPlugin.json.example`](plugins/PersonalPlugin.json.example) 为 `plugins/<InternalName>.json`。
2. 填入真实值。`InternalName` 必须与程序集名一致；一旦发布不应改名。`DalamudApiLevel` 需与插件构建时引用的 Dalamud API 对应。
3. 将三个下载链接改为真实发布 ZIP 的公开 HTTPS 地址。稳定版通常可让 `DownloadLinkInstall` 与 `DownloadLinkUpdate` 指向同一个 Release 文件。
4. 将 `LastUpdate` 设为当前 Unix 秒级时间戳，并执行：

   ```sh
   bash scripts/build-repo.sh
   ```

5. 一并提交 `plugins/<InternalName>.json` 和生成的 `repo.json`，推送到 `main`。

仓库内的 GitHub Actions 会检查每个条目的必要字段和 `repo.json` 是否已重新生成。

## 更新插件

先发布新的 ZIP，再更新相应 `plugins/<InternalName>.json` 中的 `AssemblyVersion`、下载链接和 `LastUpdate`，重新运行构建脚本并提交。`AssemblyVersion` 必须递增，否则客户端可能不会认为它是更新。

## 安全提示

自定义仓库不经过官方插件仓库的审核。只添加自己信任、并且你能审查来源与发布 ZIP 的插件；不要在插件中收集或上传玩家身份、账号或其他敏感数据。

## 参考

- [Dalamud：发布到自定义仓库](https://dalamud.dev/plugin-publishing/custom-repositories/)
- [Dalamud：插件项目布局与 manifest](https://dalamud.dev/plugin-development/project-layout/)
- [Dalamud 仓库](https://github.com/goatcorp/Dalamud)
