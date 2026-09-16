# http-meta 绕过 Android VPN / sing-box auto_redirect

Sub-Store for Android 会为 http-meta 单独设置 Android `protectedFromVpn` 标记，使其出站流量可以绕过 Android VPN。

## sing-box auto_redirect

当 sing-box TUN 开启 `auto_redirect` 时，sing-box 会额外安装透明代理规则。仅有 `protectedFromVpn` 并不能保证这些流量一定不会先被 `auto_redirect` 接管。

如果需要同时绕过 sing-box `auto_redirect`，可在 `sub_store.config` 中配置：

```sh
http_meta_bypass_auto_redirect_mark="0x200000/0xffffffff"
```

在支持于 `raw OUTPUT` 设置 `MARK` 的设备上，模块会在 sing-box 的透明代理规则之前提前设置其 output mark；随后在 `mangle OUTPUT` 末尾补上 Android `protectedFromVpn` 位，从而同时绕过 `auto_redirect` 与 Android VPN。

部分旧 Android 内核 / ROM 的 `xt_MARK` 实现仅允许在 `mangle` 表使用 `MARK`。这类设备无法使用上述方式稳定绕过 `auto_redirect`。模块会保留基础的 Android VPN 绕过，并在日志中输出警告，不会因此阻止 http-meta 启动。

如果模块日志提示当前设备不支持 `raw OUTPUT MARK`，并且你正在使用 sing-box TUN，建议关闭 `auto_redirect`，保留 `auto_route`：

```json
{
  "type": "tun",
  "auto_route": true,
  "auto_redirect": false
}
```

修改后重启 sing-box。

此时 sing-box 不再安装 `auto_redirect` 透明代理规则，http-meta 仍可依赖 Android `protectedFromVpn` 标记绕过 TUN / VPN 路由。

> `auto_redirect` 是 `auto_route` 的增强项。关闭后可能会失去 `auto_redirect` 带来的路由性能和兼容性优化，但可以避免透明代理规则与 http-meta 绕过规则之间的顺序冲突。

## 排查

查看模块服务操作日志：

```sh
cat /data/local/sub_store/run/run.log
```

查看当前 raw / mangle 规则：

```sh
iptables -t raw -S OUTPUT
iptables -t mangle -S OUTPUT
```

如果配置了 `http_meta_bypass_auto_redirect_mark`，支持的设备应能看到匹配 http-meta 独立 GID 的 raw OUTPUT 规则；基础 Android VPN 绕过规则则位于 mangle OUTPUT。
