# MTK MAC + RTL Switch 换型适配与 Ping 排障文档

目标：开发板换上一颗此前没有在该板适配过的 Realtek switch，已有驱动源码和厂商 programming manual / datasheet。完成 DTS、MAC、CPU port 与初始化适配，最终让 PC ping 通开发板。

本文按四步推进：

1. **确定设备和 driver 都在样机内，且能匹配。**
2. **确定 driver 实际完成初始化；没有初始化或初始化异常时定位原因。**
3. **确定 link 已建立，分别检查外部网线与 MAC—CPU port。**
4. **确定报文在哪一跳停止，沿 switch → CPU port → MAC → DMA → 协议栈逐段排查。**

固定示例：**Linux v6.6、MT7622 GMAC1（DTS `mac@1`）、RTL8365MB-VC、MDIO 管理、RGMII 连接 CPU port 6**。采用上游 `mtk_eth_soc`、`realtek-mdio`、`rtl8365mb` 和 DSA。寄存器与驱动行为已按该版本源码核对，未在具体开发板实测。实际板级管脚、电源、时钟和芯片后缀必须重新核对。

```text
管理面：MT7622 MDIO controller ── MDC / MDIO ── RTL8365MB-VC

数据面：
PC 网卡
   │ 网线、RJ45、磁性器件
RTL 用户口 P0 / 内置 PHY
   │ switch forwarding fabric
RTL P6 / EXT1：CPU port
   │ RGMII，1000 Mb/s、全双工
MT7622 GMAC1
   │ FE / GDMA / RX DMA / NAPI
DSA tagger → lan1 → Linux ARP / IPv4 / ICMP
```

本文假定 GMAC1 对应的 Linux 网卡叫 `eth1`，P0 对应 `lan1`。**`mac@1` 不保证一定命名为 eth1**，请先通过第一步确认实际名称，随后替换所有命令中的接口名。板子 IP 为 `192.168.10.10/24`，PC 为 `192.168.10.2/24`。

## 第一步：确定设备和 driver 都在样机内

### 1.1 要确认的是四件不同的事

| 检查对象 | 通过证据 | 不能代替它的现象 |
|---|---|---|
| 板上确有目标芯片 | 丝印、BOM、原理图与完整后缀一致 | 仅凭旧项目说明 |
| 当前系统有相应驱动 | 运行内核配置、内建信息或匹配的模块 | 仅在开发电脑中存在 `.c` 文件 |
| 当前 DT 描述了正确设备 | 运行设备树中的 MAC / MDIO / switch 节点 | 仅修改了源码 DTS |
| 总线设备与驱动已匹配 | sysfs device、driver 绑定、probe 日志 | 只有 `lsmod` 中出现模块 |

前三项存在也不等于初始化完成，第二步还要追踪真实执行路径。

### 1.2 先确认型号和接口能力

本例 RTL8365MB-VC 的四个用户端口为 P0～P3，外部接口 EXT1 对应物理 P6，可作 RGMII CPU port。v6.6 驱动用 chip ID `0x6367` 和 version `0x0040` 识别该型号。

RTL8367S 等相近型号的端口、EXT 编号和支持模式不同，不能因为同属 `rtl8365mb` 驱动就照搬 CPU port 6。所选版本的型号表按 chip ID 和 version 共同匹配，匹配后才取得对应 EXT 能力和初始化表。例如：

| 型号 | Chip ID | Version | 本文相关外部接口映射 |
|---|---:|---:|---|
| RTL8365MB-VC | `0x6367` | `0x0040` | P6 → EXT1，可使用 RGMII |
| RTL8367S | `0x6367` | `0x00a0` | P6 → EXT1 为 SGMII/HSGMII；P7 → EXT2 支持 RGMII |

因此同样读到 `0x6367` 并不足以确定 CPU port。先匹配 version，再核对实际连线与接口模式。

记录以下板级事实：

```text
SoC / MAC 实例：MT7622 / GMAC1，DTS mac@1
switch：RTL8365MB-VC，完整丝印与 revision
管理：真正的 MDIO 协议，管理地址由硬件与手册确认
数据：RGMII，接 P6 / EXT1
用户口：P0 接当前测试 RJ45
reset：对应 GPIO、有效电平、时序
供电：core / analog / I/O 电压和上电路径
时钟：switch 主参考、MAC reference、RGMII TXC / RXC
```

Realtek 的 GPIO SMI 与硬件 MDIO 可能复用相似引脚，但协议不同。本文采用 `realtek-mdio`，不使用 GPIO bitbang SMI；必须确认芯片配置与实际管理协议吻合。

### 1.3 确认运行镜像中的驱动

开发板执行：

```sh
uname -a
cat /proc/version

# 内核启用 IKCONFIG_PROC 时
zcat /proc/config.gz | grep -E \
'CONFIG_(NET_MEDIATEK_SOC|NET_DSA|NET_DSA_REALTEK|NET_DSA_REALTEK_MDIO|NET_DSA_REALTEK_RTL8365MB|NET_DSA_TAG_RTL8_4|REALTEK_PHY|PHYLINK)='
```

关键配置应包含：

```config
CONFIG_NET_MEDIATEK_SOC=y
CONFIG_NET_DSA=y
CONFIG_NET_DSA_REALTEK=y
CONFIG_NET_DSA_REALTEK_MDIO=y
CONFIG_NET_DSA_REALTEK_RTL8365MB=y
CONFIG_NET_DSA_TAG_RTL8_4=y
CONFIG_REALTEK_PHY=y
CONFIG_PHYLINK=y
```

部分选项由依赖关系自动选中，以 `olddefconfig` 解析后的配置为准；若采用模块，则对应选项可为 `m`，相关依赖也必须可用。

关键依赖关系如下：

```text
NET_DSA_REALTEK
  ├─ 依赖 NET_DSA
  ├─ 选中 FIXED_PHY、REALTEK_PHY、REGMAP 等公共支持
  ├─ NET_DSA_REALTEK_MDIO：提供硬件 MDIO transport
  └─ NET_DSA_REALTEK_RTL8365MB：提供芯片操作
       └─ 选中 NET_DSA_TAG_RTL8_4
```

只有 transport、没有芯片子驱动，或只有芯片子驱动、没有 transport，都不能完成本例适配。GPIO SMI 与 MDIO 是不同的 transport，不能因为前者被编译，就认定后者已经具备。

没有 `/proc/config.gz` 时，使用与当前样机镜像严格对应的构建配置，或者已部署的 `/boot/config-$(uname -r)`，不能拿另一个版本的配置证明当前内核支持。

模块方案继续检查：

```sh
lsmod | grep -E 'mtk|realtek|rtl8365|tag_rtl8'
find /lib/modules/"$(uname -r)" -type f \
  \( -name '*realtek*' -o -name '*rtl8365*' -o -name '*tag_rtl8*' -o -name '*mtk*eth*' \)
modinfo realtek_mdio
modprobe realtek_mdio
```

判断规则：

- `lsmod` 没有不代表驱动缺失：内建驱动不会显示在其中。
- `modinfo` 成功只证明能找到模块信息，不证明已加载、匹配或初始化。
- `modprobe` 报 unknown symbol、invalid module format、version magic 不匹配时，先修复镜像 / 模块版本，不继续排查包路径。
- MTK MAC、Realtek MDIO transport、RTL 型号子驱动和 tagger 缺任意一层，都可能无法正常工作。

### 1.4 确认当前运行的 DTS

```sh
cat /proc/device-tree/model
tr '\0' '\n' < /proc/device-tree/compatible

# 开发板装有 dtc 时
dtc -I fs -O dts /sys/firmware/devicetree/base > /tmp/running.dts
grep -nE 'mac@1|mdio-bus|realtek,rtl8365mb|fixed-link|rgmii' /tmp/running.dts
```

没有 dtc 时，也可读取 `/sys/firmware/devicetree/base` 的相应属性；二进制 cell 用 `hexdump` 解释，不把 phandle 的数字当字符串。

必须核对：

1. `&eth` 和 `mac@1` 启用，实际引出的确是 GMAC1。
2. 管理子节点名是本例 MTK 驱动寻找的 **`mdio-bus`**。
3. switch 在该 MDIO bus 下，compatible 为 `realtek,rtl8365mb`。
4. switch 管理地址与板级配置一致。
5. CPU `port@6` 的 `ethernet` 指向 `gmac1`，不是指向整个 eth controller。
6. MAC、switch CPU port 都有一致的 1000/full fixed-link。
7. 旧 switch、旧 PHY、旧 GPIO reset 配置未与新设备冲突。
8. pinctrl、参考时钟、电源、reset 与新原理图一致。

### 1.5 可用于集成的 DTS 框架

下面是加入实际 MT7622 板级文件的**增量片段**。假定基树已有 `eth`、`pio`，并定义正确的 `eth_rtl_pins`、`rtl_reset_pins`。RESET_N 示例使用 GPIO54，不能直接认作实际板子的接线。

管理地址示例为 **十进制 29，即 0x1d**，因此写作 `switch@1d`、`reg = <29>`。它是管理入口地址，**不是 CPU port 号、不是内置 PHY 0 的地址，也不是 switch 寄存器地址**。

```dts
#include <dt-bindings/gpio/gpio.h>

&eth {
    pinctrl-names = "default";
    pinctrl-0 = <&eth_rtl_pins>;
    status = "okay";

    gmac1: mac@1 {
        compatible = "mediatek,eth-mac";
        reg = <1>;
        phy-mode = "rgmii";
        /* 若继承了旧 phy-handle，在实际节点中删除。 */
        fixed-link {
            speed = <1000>;
            full-duplex;
        };
    };

    mdio-bus {
        #address-cells = <1>;
        #size-cells = <0>;
        clock-frequency = <1000000>;
        status = "okay";

        switch@1d {
            compatible = "realtek,rtl8365mb";
            reg = <29>;
            pinctrl-names = "default";
            pinctrl-0 = <&rtl_reset_pins>;
            reset-gpios = <&pio 54 GPIO_ACTIVE_LOW>;

            ports {
                #address-cells = <1>;
                #size-cells = <0>;

                port@0 { reg = <0>; label = "lan1"; };
                port@1 { reg = <1>; label = "lan2"; };
                port@2 { reg = <2>; label = "lan3"; };
                port@3 { reg = <3>; label = "lan4"; };

                port@6 {
                    reg = <6>;
                    ethernet = <&gmac1>;
                    phy-mode = "rgmii";
                    tx-internal-delay-ps = <2000>;
                    rx-internal-delay-ps = <2100>;
                    fixed-link {
                        speed = <1000>;
                        full-duplex;
                    };
                };
            };
        };
    };
};
```

说明：

- MDIO 版本的 Realtek DSA 操作提供 `.phy_read` / `.phy_write`，通过驱动访问内置 PHY；不要把它们不加判断地声明成外部 SoC bus 上的普通 PHY。
- 本例不在 switch 下添加 GPIO SMI 方案使用的 `realtek,smi-mdio` 节点。
- 1 MHz 用于首轮管理调试，之后仍须用波形核对实际 MDC 和手册限制。
- 两个 delay 值仅是“switch 提供延迟，MAC / PCB 不重复提供”的示例方案。RTL 驱动 TX 是 0 或 2 ns，RX 按约 0.3 ns 步进，2100 ps 对应最大档；实际板子必须做时序预算。
- 此版本 RTL 驱动显式解析 `*-internal-delay-ps`，不靠 `rgmii-id` 字符串自动选择这两个值。
- MT7622 的 pinctrl 应含 `mdc_mdio` 与实际 GMAC RGMII 路径；参考板出现 `rgmii_via_gmac2` 这一组名，不能据名字把 `mac@1` 再加一或改成不存在的 `mac@2`。
- 已有相同 MAC / MDIO 节点时合并修改，禁止新增重复节点；旧 PHY 的 `phy-handle` 与 fixed-link 不能同时描述同一条连接。

这份 DTS 框架对应的驱动解释关系如下：

| DTS 内容 | 谁解析 | 产生的效果 |
|---|---|---|
| `mac@1`、`reg = <1>` | MTK Ethernet controller | 创建 GMAC1 对应的 netdev / phylink |
| `mdio-bus` | `mtk_mdio_init()` | 注册硬件 MDIO bus |
| `clock-frequency` | MTK MDIO 初始化 | 计算 MDC 分频，并检查允许范围 |
| `switch@1d`、`reg = <29>` | MDIO core / Realtek transport | 注册地址为 29 的 switch 管理设备 |
| `realtek,rtl8365mb` | Realtek driver 匹配 | 选择 RTL8365MB 家族的 detect / setup 操作 |
| `port@6`、`ethernet = <&gmac1>` | DSA | 将 P6 关联到 GMAC1 conduit |
| `fixed-link` | 两端 phylink | 按静态参数配置 CPU 数据链路 |
| 两项 internal delay | RTL 的 RGMII 配置回调 | 设置 EXT1 的 TX/RX delay 档位 |

不要给未实现解析的属性寄希望：DTS 写入一个字符串或数值，不会自动产生相应硬件动作。

构建后把 kernel、DTB、模块作为同一版本部署。示例构建检查：

```sh
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j8 Image dtbs modules
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs_check \
  DT_SCHEMA_FILES=net/dsa/realtek.yaml
```

以上在配置好工具链及 dtschema 的构建环境执行；DTB 可编译不代表与硬件接线一致。

### 1.6 最后确认 device 与 driver 的绑定

```sh
ls /sys/class/mdio_bus
ls /sys/bus/mdio_bus/devices
ls -l /sys/bus/mdio_bus/drivers/realtek-mdio
ls -l /sys/bus/platform/drivers/mtk_soc_eth
ip -br link
ethtool -i eth1
ip -d link show lan1

# 确认接口属于哪个 DT 节点；以实际路径为准
readlink -f /sys/class/net/eth1/device/of_node
```

MDIO 设备名中的地址通常按十六进制显示，本例应对应 `...:1d`。找到真实设备后检查其 `driver` 符号链接，确认绑定到 `realtek-mdio`。不要假定 bus ID 固定，也不要看到任意一个 `...:00` 就认作本例 switch。

**本步通过标准：**当前样机有正确镜像和 DT，MTK MAC driver 存在，MDIO bus 与 switch device 存在，目标 driver 能匹配；物理型号和接线已确认。下一步再证明 probe / setup 真正完成。

## 第二步：确定 driver 正常初始化完成

### 2.1 驱动在系统里，不等于已经初始化

将状态分成四类：

| 状态 | 典型证据 | 排查入口 |
|---|---|---|
| 没进 probe | 没有入口日志、没有成功绑定 | 匹配、总线、模块、DT |
| 进了 probe，未进芯片 setup | ID / reset / DSA 前置检查失败 | transport、芯片识别、依赖 |
| 进了 setup，但中途失败 | 有阶段日志，缺少完成日志 | 最后成功阶段与第一个错误 |
| setup 返回成功，运行配置不对 | 网卡出现但读回不符 | 漏配、覆盖、后续 reset、错误被吞掉 |

`found an RTL8365MB-VC switch` 只表示 detect 识别成功，**不是整个初始化完成**。网口 LED 亮也可能来自 strap、EEPROM 或 bootloader，不能反证 Linux driver 完成过初始化。

### 2.2 本例真实执行主线

```text
mtk_probe()
  → mtk_mdio_init() 注册 MDIO bus
  → MDIO core 根据 DT 注册 switch mdio_device
  → realtek_mdio_probe()
      → 建 regmap、设置 bus / mdio_addr
      → reset GPIO 硬复位与等待
      → rtl8365mb_detect()
          → 读取 chip ID / version，选择型号参数
      → dsa_register_switch()
          → rtl8365mb_setup()
              → rtl8365mb_reset_chip()
              → rtl8365mb_switch_init()：型号 jam table + common table
              → IRQ 设置（本例可使用轮询）
              → CPU tagging / trap port 配置
              → isolation、learning、初始 STP 状态
              → MTU、统计资源等
          → DSA 用户网卡、内置 PHY / phylink 注册

端口打开及 phylink 配置期间：
  → mtk_mac_config() / mtk_mac_link_up()
  → rtl8365mb_phylink_mac_config()
  → rtl8365mb_ext_config_rgmii()
  → rtl8365mb_phylink_mac_link_up()
  → rtl8365mb_ext_config_forcemode()
```

这是主线，不是逐行时序；probe 依赖、DSA 注册和端口启停会影响回调发生时间。MAC / CPU port 的运行配置不能只在 setup 返回前检查一次。

### 2.3 用阶段日志证明执行到了哪里

先收集完整启动日志：

```sh
dmesg > /tmp/boot-network.log
grep -Ei 'mtk|mdio|realtek|rtl8365|dsa|phy|defer|timeout|error|fail' \
  /tmp/boot-network.log
```

没有足够日志时，在所选源码的关键边界补上入口、出口、ret 与必要参数。例如给现有调用加日志：

```c
/* 加在 rtl8365mb_setup() 的原有初始化调用周围，保留原错误回滚。 */
dev_info(priv->dev, "S20 vendor init begin\n");
ret = rtl8365mb_switch_init(priv);
if (ret) {
    dev_err(priv->dev, "S20 vendor init failed: %d\n", ret);
    goto out_error;
}
dev_info(priv->dev, "S20 vendor init done\n");
```

建议日志边界如下，编号仅用于本次定位，不是上游已有输出：

```text
S00 realtek_mdio_probe enter：bus、addr
S10 detect done：chip_id、chip_ver、型号
S15 chip reset done
S20 vendor jam init done
S30 CPU tag / trap port configured
S40 port isolation / learning / STP / MTU configured
S50 rtl8365mb_setup returned 0
S60 dsa_register_switch returned 0 / realtek_mdio_probe success
S70 port open / phylink：port、interface、speed、duplex、link
```

记录最后成功阶段和第一个失败阶段。不要只加“init done”打印，却没有检查实际返回值；也不要把 `return 0` 提前移动来消除报错。

如现有源码有 `dev_dbg()`，可使用 dynamic debug；它只打开已有日志，不会自动生成上述阶段点。内建驱动首轮 probe 的日志需要启动参数或重启后的插桩镜像，启动后才开启调试不能回放此前执行。

### 2.4 没做初始化、没进 probe：怎么查

按依赖顺序检查：

1. **内核是否真的包含该 driver？** 模块是否加载，加载是否报错，当前 kernel 与模块是否匹配。
2. **MTK controller 是否 probe 成功？** 先看 MAC clocks / reset / power-domain / pinctrl 的错误。
3. **MDIO bus 是否注册？** 本例代码寻找 `mdio-bus`，拼成其他名称会影响注册。
4. **switch device 是否存在？** 查运行树、`status`、管理地址、旧设备地址冲突。
5. **compatible 是否匹配？** 型号家族用 `realtek,rtl8365mb`，不是随意写丝印全名。
6. **是否卡在 defer？** debugfs 挂载后看 `/sys/kernel/debug/devices_deferred`，保留 `-EPROBE_DEFER`，定位未就绪 supplier。
7. **是否进入 detect 后退出？** 此时已经做过部分初始化，转入寄存器 / ID 分支。
8. **厂商 SDK 架构是否漏掉启动入口？** 如果不是本文 DSA 驱动，检查 SDK init 的调用者、模块入口、启动服务、条件编译和日志；仅将 SDK 库打进 rootfs 不会自动执行。

本例已采用 DSA，初始化入口由 driver / DSA 调用，不需要另起用户态程序才能执行 `rtl8365mb_setup()`。如果实际工程选择厂商 SDK，要把这个差异明确写在项目架构里，避免两套初始化同时运行。

### 2.5 初始化异常：先证明 MDIO 寄存器访问正常

#### 2.5.1 本例不是“PHY 地址 + 全局寄存器地址”直接读

`realtek-mdio` 通过 Clause 22 的 command / address / data 寄存器，间接访问 switch 的 16 位寄存器。以管理地址 `M = 29` 为例，逻辑事务为：

```text
读 switch 寄存器 A：
  MDIO write(M, reg31, 0x000e)
  MDIO write(M, reg23, A)
  MDIO write(M, reg21, 0x0001)
  value = MDIO read(M, reg25)

写 switch 寄存器 A = V：
  MDIO write(M, reg31, 0x000e)
  MDIO write(M, reg23, A)
  MDIO write(M, reg24, V)
  MDIO write(M, reg21, 0x0003)
```

这里 reg31 / reg23 是 **Clause 22 寄存器编号**，A 是 **switch 内部地址**。不能写成 `mdiobus_read(bus, 29, 0x1300)` 来读芯片 ID。

事务整体由 transport 持有 `bus->mdio_lock`，避免 address / command 被并发访问覆盖。持锁期间调用底层 `bus->read()` / `bus->write()`；不要再次调用会自动获取同一把锁的接口而造成递归死锁。

例如，错误并发可能发生：

```text
线程 A：选择内部地址 0x1300
线程 B：选择内部地址 0x1307
线程 A：执行读取
结果：A 读到的可能已经不是 chip ID
```

必须保护“选模式 → 写地址 → 发命令 → 取数据”整个序列。不要让独立工具、SDK 与驱动后台统计同时操作这个管理窗口。

#### 2.5.2 正确读取 chip ID / version

该驱动读取 ID 前需要 magic 序列：

```text
switch write 0x13c2 = 0x0249
switch read  0x1300 → chip ID
switch read  0x1301 → chip version
switch write 0x13c2 = 0

RTL8365MB-VC 示例期望：ID 0x6367，version 0x0040。
```

优先在已有 `rtl8365mb_get_chip_id_and_ver()` / detect 路径记录结果和 errno，不另写省略 magic 的裸读程序。ID 返回其他值时先核对真实型号和版本，不修改 ID 比较强行通过。

连续读取验证时遵循相同完整流程、按需要串行化 magic 访问，并保持设备状态稳定；不要与另一个独立工具或 SDK 并发写管理窗口。

#### 2.5.3 无法读取寄存器时按以下顺序查

| 证据 | 优先检查 | 下一项验证 |
|---|---|---|
| 没有 MDC | MTK MDIO clock、注册、pinmux、controller | 事务是否真正发到引脚 |
| 有 MDC，但地址不对 | MDIO 地址、工具十进制 / 十六进制、错 bus | 解码 PHYAD / REGAD |
| read TA 无响应 | 管理模式、芯片供电、reset、参考时钟、接线 | MDIO 是否被芯片接管 |
| 全 0xffff | 未响应、上拉、高阻、错误事务 | 看 TA；不是直接认定未供电 |
| 全 0 | 下拉、短路、reset、或合法零字段 | 读有已知值的 ID，不只读零寄存器 |
| 每次随机 | 电压、上拉 RC、边沿、地、MDC 过快 | 降频并看稳定采样窗口 |
| ID 错但读值稳定 | 间接协议、magic、实际型号 | 对照真实手册与线上序列 |
| ID 对，其他寄存器错 | 地址空间、访问权限、复位状态、并发 | 用已知只读普通寄存器对照 |
| 冷启失败、热启成功 | 上电等待、reset、首轮访问、bootloader 残留 | 完全断电记录波形 |

Clause 22 read 的 turnaround 应出现控制器释放、目标设备按协议驱动的阶段。主机始终驱动 MDIO、缺上拉、I/O 电压不匹配、多 master 冲突都能造成读值错误。控制器返回“事务完成”不等于读到了真实芯片数据。

从芯片附近测供电和 reset，核对 strap 在采样瞬间的电平；不能只在 Linux 启动后读一次 GPIO 就断定启动配置正确。厂商给出的管理初始化时序、busy 轮询、W1C 和保留位要求优先逐条执行。

### 2.6 reset / jam table 出错时怎么查

本例存在两个 reset 层次：

- `realtek_mdio_probe()` 可通过 GPIO 做硬复位，驱动定义保持约 25 ms、释放后等待约 100 ms。
- `rtl8365mb_setup()` 又调用芯片 reset；该路径先等约 100 ms，再轮询 reset 位清除，超时上限约 1 s。

因此 detect 已成功、后续访问暂时失败时，先看是否处于第二次 reset 等待期，不能据此认定管理接线随机失效。

jam table 是所选驱动的厂商初始配置序列：

1. 确认按正确 chip ID / version 选中型号表。
2. 记录失败 entry 的 index、reg、value、errno。
3. 确认 common table 同样执行，没有只执行型号表。
4. 对照厂商手册 / SDK 版本核查必要的 patch 与顺序。
5. 检查忙位、模拟模块上电、PHY/OCP 访问是否需要等待。
6. 配置寄存器按读写属性抽查；写-only、self-clear、W1C 或 patch 窗口不能机械要求“读回等于写入”。
7. 检查初始化后是否又被 watchdog、其他驱动、bootloader handoff、第二个 SDK 或电源管理 reset 覆盖。

`no interrupt support` 在此版本可代表退回无 IRQ 的工作路径，不等于整个初始化失败；但 defer、无法完成 setup 和注册失败都必须追踪，不能吞掉。

### 2.7 setup 成功后读回关键运行状态

用户口和 CPU port 打开后，再采集一次：

| 配置 | 本例 switch 地址 / 对象 | 验证内容 |
|---|---|---|
| 芯片识别 | 0x1300 / 0x1301，按 magic 流程 | 型号、version |
| reset | 0x1322 | reset 已完成 |
| EXT1 接口 | 0x1305 对应字段 | RGMII，而非 MII / RMII |
| EXT1 delay | 0x1307 | TX / RX 档位符合板级时序 |
| EXT1 force | 0x1311 | force enable、link、1000/full |
| CPU mask / CPU control | 0x1219 / 0x121a | CPU P6、trap port、tag enable / 格式 / 位置 |
| P0 isolation | 0x08a2 | 允许本测试通往 CPU 的路径 |
| 端口 STP / MAC / PHY | 对应手册与 driver | 用户口启用后可收发 |
| MTK GMAC1 | 对应 SoC MAC control / status | 正确路径、速率、双工、RX/TX enable |

以上是 switch 内部地址，必须经 Realtek MDIO transport 访问；不能当成 CPU MMIO 用 `devmem` 读取。MTK MAC 的 MMIO 属于另一套地址空间，按 MT7622 手册和本驱动的寄存器映射检查，不能照搬其他 MTK SoC 的偏移。

初始 setup 会将端口 STP 状态设为 disabled，之后由 DSA 端口状态转换启用；**setup 返回时的快照和 `ip link set lan1 up` 后的快照含义不同**。初始化完成也不等于 PHY 状态机和 MAC 已在 down 接口上启动。

**本步通过标准：**detect、reset、jam、CPU 配置、DSA 注册均有成功证据；打开接口后两端运行配置读回正确，无未处理错误。到此才进入 link 排查。

## 第三步：检查有没有 Link 上

### 3.1 正常情况下什么时候应该 Link

在电源 / 时钟 / reset 正常、PHY 已初始化并启用、用户端口 administratively up、PC 网卡启用且网线正常的前提下，外部 PHY 应自动协商并建立 link；**不需要先配 IP，也不需要先 ping。**

所以初始化后首先看 link 是正确顺序。但要分别检查两段：

| 链路 | 本例机制 | 可靠证据 |
|---|---|---|
| PC ↔ RTL 用户口 PHY | 铜口自动协商 | 双方 PHY link、协商完成、speed / duplex |
| MTK GMAC1 ↔ RTL P6 | RGMII fixed-link | 两端配置读回、时钟与真实收发 |

### 3.2 先打开接口，再观察铜口

```sh
ip link set dev eth1 up
ip link set dev lan1 up
ip -br link
ethtool lan1
ethtool eth1
```

对 `lan1` 期望：Link detected yes、正确 speed / duplex、PC 侧也一致。通过拔插当前 RJ45，确认变化的确是 `lan1` / P0，而非另一个端口。

不要只看 LED；LED 功能可能可编程。读取 PHY BMSR 时注意 latch-low 等语义，结合 PHYLIB 当前状态与重复读取判断。

### 3.3 外部铜口 Link 不上

按顺序检查：

1. **端口对不对？** 丝印、RJ45、P0、PHY、`lan1` 的映射是否一致。
2. **双方是否启用？** PC 网卡、Linux 用户口、PHY power-down / isolate / reset 状态。
3. **是否完成 PHY 初始化？** jam / OCP / PHY driver 初始化是否报错。
4. **自动协商是否开启，广告是否合理？** 查看对端能力、协商完成、master/slave fault。
5. **网线 / PC 是否正常？** 换已知正常的短线和网卡。
6. **磁性器件和模拟电路是否符合新芯片要求？** 线对、中心抽头、电源、终端与器件型号。
7. **千兆失败而百兆正常？** 优先查线对、千兆协商与 PHY 模拟路径。
8. **状态变化只靠轮询还是 IRQ？** PHY 硬件 link 已变但 Linux 不更新时，检查中断、轮询和 bus 访问，不重复改协商设置。

可受控限制广告到 100/full 做对比，双方仍保持自动协商；不要一端强制、另一端自动后，把结果当可靠的 full-duplex 对照。1000BASE-T 的协商机制也不能用“直接关闭 autoneg”一概替代。

### 3.4 MAC 与 switch 的速率“协商”是否正常

**本例 RGMII CPU 链路不执行网线侧那样的自动协商。** DTS fixed-link 和 phylink 把两端配置成 1000/full。这里需要验证的是“配置是否一致且真正生效”，不能等待一个并不存在的自动协商完成事件。

检查：

```text
MTK mtk_mac_config()：实际选中 GMAC1 的 RGMII 路径
MTK mtk_mac_link_up()：speed=1000，duplex=full，TX/RX enable
RTL rtl8365mb_ext_config_rgmii()：P6 / EXT1，RGMII，正确 delay
RTL rtl8365mb_ext_config_forcemode()：link=1，speed=1000，full
```

读回 MTK MAC control 与 RTL 0x1311；比较实际值，不能只比较 DTS。fixed-link 在软件中显示 up，只证明 phylink 按配置宣告链路，不证明引脚、时钟与数据都正确。

若实际项目使用 SGMII / 1000BASE-X，需要另查 PCS、SerDes PLL、lane、参考时钟、模式和 in-band 协商角色；不能将本例 RGMII 的 force 结论套过去。

三种模式应分别理解：

| 模式 | 参数来源 | 检查重点 |
|---|---|---|
| PHY 模式 | 真实 PHY 的协商结果，经 PHYLIB / phylink 通知 MAC | PHY link、解析出的 speed/duplex、MAC 是否跟随 |
| Fixed-link | 固件描述的静态参数 | 两端配置一致、寄存器生效、物理收发正常 |
| In-band | SerDes 链路内传递的状态/控制字 | PCS、协议、角色、协商完成、状态同步 |

仅写 `phy-mode = "sgmii"` 不足以证明启用了正确的 in-band 模式。实际拓扑、驱动能力和两端配置必须匹配。

### 3.5 CPU RGMII 通道的物理检查

- SoC → switch 的 TXC / TXD / TX_CTL 有效。
- switch → SoC 的时钟 / 数据 / control 有效，实际信号方向按两端 datasheet 核对。
- 千兆 RGMII 时钟通常为 125 MHz，百兆 25 MHz，十兆 2.5 MHz；分别测两个方向，不把 switch 主晶振当成接口时钟。
- 电压、pinmux、输入选择、驱动强度与走线符合要求。
- 两个方向分别满足接收 setup / hold；延迟总预算包含 MAC、switch 与 PCB。
- 不把 TX/RX 名称直接当作方向定义；Realtek 的 delay 字段应对照其手册解释到真实线路。

一个方向不能双重加延迟，也不能完全缺失。若测试 CPU 链路降速，应同时改 MTK 与 RTL 两端 fixed-link / force 配置；**只让外部铜口降到 100M，不会自动使 CPU RGMII 从 1000M 降到 100M。**

**本步通过标准：**PC—RTL 铜口有真实 link、参数一致；MTK—RTL CPU 链路两端配置及接口时钟正常。下一步用报文证明实际收发通道。

## 第四步：Link 已上，为什么 Ping 不通

### 4.1 先建立一个最小可判断的测试环境

首轮只测一个用户口和静态 IPv4，不先加入复杂 bridge / VLAN / NAT。假定相关接口没有其他测试 IP，也没有被网络管理服务覆盖，在开发板串口执行：

```sh
ip link set dev eth1 up
ip link set dev lan1 up
ip addr add 192.168.10.10/24 dev lan1
ip -br addr
ip route get 192.168.10.2
```

PC Linux 示例，`enp3s0` 换成实际有线网卡：

```sh
sudo ip link set dev enp3s0 up
sudo ip addr add 192.168.10.2/24 dev enp3s0
ip route get 192.168.10.10
```

本例 IP 配在 `lan1`，不配在 conduit `eth1`；同一测试子网不要同时配到多个接口。

| 网络对象 | 本例用途 | IP 放置 |
|---|---|---|
| `eth1` | MTK GMAC1 / DSA conduit，运输 CPU tag 帧 | 本次不配置测试 IP |
| `lan1` | DSA 用户口 P0，单端口测试入口 | `192.168.10.10/24` |
| `br0` | 后续可创建的多用户口 bridge | 采用桥接模式时把 IP 迁移到 br0 |
| RTL CPU P6 | switch 侧 CPU 通道 | 没有独立普通 IP 网卡 |

如果实际使用 bridge，应检查 `lan1` 是否属于正确 bridge、bridge/VLAN 状态及本机 IP 落点，再调整抓包与回程路由观察点。不要把 conduit `eth1` 当作普通外部 LAN 口加入该 bridge。

先检查 IP / 路由 / 端口映射，避免硬件正常却一直发往错误网卡。PC 的 VPN、Wi-Fi、其他 NIC 不应抢占同一个测试子网。

### 4.2 把 Ping 拆成 ARP 与 ICMP

```text
第一阶段：ARP
PC 发广播：谁有 192.168.10.10？
  → RTL P0 RX
  → switch 决定转发到 CPU
  → RTL P6 TX
  → MTK GMAC1 RX
  → DMA / NAPI / DSA
  → lan1 / ARP
板子回 ARP reply：我的 MAC 是 ...
  → 相反方向返回 PC

第二阶段：ICMP
PC 得到 MAC 后发 echo request
  → 同一路径进入板子 IPv4 / ICMP
板子生成 echo reply
  → 相反方向返回 PC
```

ARP 没完成时，先定位 ARP 的丢失位置；不要把尚未发出的 ICMP 当成“进入 switch 后被丢掉”。

**方向约定：switch CPU port RX = MTK → switch；CPU port TX = switch → MTK。** “CPU port 收到 PC 的数据了吗”在硬件计数器上要拆开：PC 包先进入用户口 RX，再由 CPU port **TX** 发给 MTK；只有 MTK 向 switch 发包时，CPU port 的 **RX** 才增长。

### 4.3 一次测试同时收集哪些证据

开发板两个终端：

```sh
# 终端 A：去 tag 后的用户口帧
tcpdump -pni lan1 -e -vv 'arp or icmp'

# 终端 B：原始 CPU 通路先不加协议过滤，防止 tag 改变解析位置
tcpdump -pni eth1 -e -xx
```

PC：

```sh
sudo tcpdump -pni enp3s0 -e -vv 'arp or icmp'
```

在另一个 PC 终端发起：

```sh
ping -I enp3s0 -c 5 192.168.10.10
ip neigh show dev enp3s0
```

需要重新产生 ARP 时，可只删除该测试邻居项，或用 `arping`：

```sh
sudo ip neigh del 192.168.10.10 dev enp3s0
sudo arping -I enp3s0 -c 5 192.168.10.10
```

邻居项不存在时删除命令会报错，确认原因即可。没有 arping 时清除目标邻居后发 ping，同样可以观察 ARP。

同时在测试前后各采集一次：

```sh
ip -s -s link show dev lan1
ip -s -s link show dev eth1
ethtool -S lan1
ethtool -S eth1
cat /proc/interrupts
```

比较增量，保持背景流量尽量安静。`tcpdump` 看到本机发送包只表示经过软件发送观察点，不证明 DMA 完成或线上发送成功；坏 CRC 帧也可能在抓包前就被硬件丢弃。

本例 RTL 驱动还会把硬件 MIB 整理到用户口的标准统计中，所以 **`ip -s link show lan1` 的 RX 增长不必然证明帧已经成功解 tag 并递交到 lan1 的软件接收路径**。确认 DSA 递交应结合 lan1 抓包、tagger 分支计数或协议栈证据；不要把同一套 MIB 在两个接口中的显示当成两跳独立证据。

### 4.4 数据包到 switch 了吗：查用户口 RX

**问题：PC 的 ARP / ICMP 有没有真正到达 RTL P0？**

证据：P0 MIB 的输入字节、广播 / 单播包增长，同时观察 FCS、symbol error、discard。`ethtool -S lan1` 在本驱动通过用户口 MIB 读取这些统计，名称例如：

```text
ifInOctets
ifInUcastPkts
ifInBroadcastPkts
ifInMulticastPkts
dot3StatsFCSErrors
dot3StatsSymbolErrors
etherStatsDropEvents
```

| 结果 | 含义与下一步 |
|---|---|
| PC 抓到发送，P0 RX 没有相应增长 | 查实际插口、映射、网线、PHY RX、link 参数 |
| P0 RX 有增长但错误增加 | 查铜口物理层、协商参数和帧格式 |
| P0 有合法广播增长 | 报文至少到 switch 入口；继续查转发 |

不要用累计几百万个包证明刚才五个 ARP 已进入；比较同一短窗口的增量，确认统计读数正常。

### 4.5 switch 把包发给 CPU port 了吗：查 P6 TX

**问题：报文进入 P0 后，switch 是否向 MTK 所接的 P6 发出？**

P0 RX 增长而 P6 TX 无对应增长，重点看：

1. CPU mask / trap port 是否指向 P6，是否误配 P5、P7 或 PHY 地址。
2. 用户口 isolation / member 是否允许到 CPU。
3. STP 状态是否仍 disabled / blocking。
4. VLAN ingress、PVID、CPU membership、tagged / untagged egress 是否一致。
5. 广播 / 未知单播 / 已知单播是否分别允许到 CPU。
6. ACL、storm control、端口过滤、CPU tag 插入配置是否丢包。
7. MAC / CPU port 是否被禁用，或初始化后被其他 SDK 改写。

本例 standalone 模式由 DSA 管理转发配置，不必为单口 ping 先把所有端口放进一个 bridge，也不能拿别的芯片的 port member 位图直接写入 RTL。

**CPU port 没有独立普通网卡。** `ethtool -S lan1` 是 P0，`ethtool -S eth1` 是 MTK 侧；它们都不能替代 RTL P6 的硬件 MIB。

若现有接口未导出 P6 MIB，应在驱动中增加受控只读 debug 接口，复用 `rtl8365mb_mib_counter_read()`，按现有 `mb->mib_lock` 保护“选 port / counter → 等待 busy → 读结果”的完整序列。此处读取的 port index 为 **6**。不要伪造一个不存在的 `ethtool -S cpu0` 命令，也不要绕过驱动并发操作间接 MIB 窗口。

P6 TX 增长是重要证据，但也要核对计数器统计点：硬件计数并不能单独证明接收端已成功采样，需要下一跳证据。

### 4.6 CPU port 速率、Link 与 RGMII 是否真正正常

P6 TX 增长，而 MTK RX 没有有效增长时，回到第三步的 CPU 链路检查：

```text
P6 / EXT1 force：link=1，1000/full
MTK GMAC1 control：1000/full，RX enable
两端接口：RGMII
两方向时钟与电压：正常
延迟：匹配板级时序
```

重点排查 switch → MTK 方向的时钟、数据、control、pad 输入选择和接收时序。如果 MTK CRC / alignment / length 错误随流量增长，优先核对该方向信号与帧长。

测试反向通信时也单独检查 MTK → RTL 方向。只有一个方向丢包，不能同时随机改两方向 delay。

### 4.7 数据包到 MTK MAC 了吗：分硬件 MAC 与 DMA 两层

**问题一：GMAC1 的接收硬件有没有接到合法帧？**

- 读取 `ethtool -S eth1` 与对应 GDMA / MAC 硬件统计。
- 核对 byte / packet / FCS / length / overflow 的实际实现和统计位置。
- 确保读的是 GMAC1，不是另一 MAC，不能凭“eth1”名称推断寄存器实例。

**问题二：合法帧有没有形成 CPU 能处理的 RX descriptor？**

若 MAC 硬件计数增长，但驱动未观察到相应 descriptor：

1. 查 FE / GDMA 的转发目的是否为正确 CPU RX DMA。
2. 查 RX DMA ring base、buffer、enable、descriptor ownership / done。
3. 查 RX interrupt mask、状态及 `/proc/interrupts` 增量。
4. 查 NAPI 是否被 schedule、是否运行到 `mtk_poll_rx()`。
5. 查 ring full、buffer 分配失败、DMA mapping、IOMMU / coherency / cache 问题。
6. 查 PPE、硬件 flow offload、XDP 等是否改变了原本期望的 CPU 路径。

这里不要简单说“中断没增长就硬件没收包”：中断合并、NAPI polling 和统计窗口都会影响表现。要把 MAC 计数、descriptor 和 NAPI 三者一起看。

### 4.8 MTK driver 收到包后，有没有往上传

v6.6 本例接收主线可按以下位置观察：

```text
RX descriptor done
  → mtk_poll_rx()
      → 从 descriptor 解析实际来源 MAC
      → 校验状态、长度与 buffer
      → XDP 路径（如启用）
      → 构建 skb，设置 skb->dev
      → eth_type_trans()
      → napi_gro_receive()
  → Linux 接收路径
  → DSA 分发 / rtl8_4_tag_rcv()
  → 将 skb 归属到 lan1，剥离 Realtek tag
  → ARP 或 IPv4 协议栈
```

各阶段的职责与失败表现如下：

| 位置 | 应完成的工作 | 卡住时的表现 |
|---|---|---|
| `mtk_poll_rx()` | 取 descriptor，解析来源 MAC，获取长度与 buffer | 硬件有流量，但没有 skb 或归属错误 |
| skb 构建与 `eth_type_trans()` | 设置 netdev 和协议类型，准备向网络栈递交 | descriptor 已消费，但软件接收点没有包 |
| `napi_gro_receive()` | 把 skb 送入接收处理 | 需要继续检查后续 DSA / 协议分发 |
| `rtl8_4_tag_rcv()` | 校验 Realtek tag，定位来源端口，去 tag | conduit 有包，lan1 没有有效包 |
| ARP / IPv4 / ICMP | 判断本机地址，处理 request，生成 reply | lan1 已看到正确 request，但没有应答 |

函数进入日志不能替代返回结果和分支计数。例如 `mtk_poll_rx()` 被调用，并不证明本次测试包真的被取出；需要确认它对应的 descriptor 和实际递交分支。

若 descriptor 已到但没有向上递交，建议增加计数而非逐包刷日志：

```text
rx_desc_seen
rx_bad_source_mac
rx_bad_length
rx_alloc_failed
rx_xdp_drop_or_redirect
rx_skb_built
rx_to_napi_gro
rtl_tag_seen
rtl_tag_bad_type_or_protocol
rtl_tag_bad_source_port
rtl_tag_delivered_to_lan1
```

以上是建议新增的调试计数，不是已有 ethtool 标准字段。每个计数应对应实际分支，发送固定数量报文看增量，最后移除或纳入正式调试接口。

特别检查两类 MTK 适配点：

- **来源 MAC 解析。** descriptor 的 source port / special-tag 状态是否导致包被归到 GMAC0，或落到未启用 netdev 后丢弃。
- **MTK 专有 tag 解析与卸载。** 原板如果接 MT753x，可能有针对 MTK special tag 的解析、VLAN untag 或 DSA metadata 路径。更换为 RTL 后，必须核对硬件 parser、VLAN strip、descriptor 标志和 offload，不能只因 `netdev_uses_dsa()` 为真就认定该包使用 MTK tag。

本版 MTK 驱动确有 MTK special-tag / DSA metadata 相关代码。是否误触发要由原始帧和 descriptor 证明；不要在没有证据时全局关闭共享 FE 功能，影响另一条 MAC 的连接。

### 4.9 MAC 有包、lan1 没包：查 Realtek tag 与 DSA

本例 detect 默认配置普通 header 型 **`rtl8_4`**：8 字节 tag 位于源 MAC 后、原始 EtherType 前。

```text
外部铜口帧：
DA | SA | EtherType | payload | FCS

CPU RGMII 帧：
DA | SA | 8-byte RTL tag | EtherType | payload | FCS
```

其中 Realtek EtherType 为 `0x8899`，protocol 为 `0x04`。芯片也可支持尾部位置，对应 `rtl8_4t`，两者不能一边配置 header、一边用 tail tagger 解释。

```sh
cat /sys/class/net/eth1/dsa/tagging
```

默认应为 `rtl8_4`。同时读回 CPU control 的 tag enable、format、position，检查：

1. 8 字节没有被 MAC 硬件当成 MTK tag 或 VLAN 错误剥离。
2. DSA 使用正确 tagger，协议字段可识别。
3. 来源用户端口是 P0，并能映射到 `lan1`。
4. 最大帧长能容纳 tag；padding / FCS / DMA 上报长度符合 driver 预期。
5. MAC 过滤允许本机和所需广播帧进入。
6. checksum / VLAN / GRO / GSO 的能力声明与真实 tag 格式兼容。

如需对比卸载，先记录 `ethtool -k eth1`，再针对性关闭支持的特性并读回；不支持的选项会报错，不能宣称一次 `ethtool -K` 已全部关闭。调试确认后修复相关路径再恢复。

抓包默认开启混杂模式可能改变 MAC 过滤，所以本文先使用 `tcpdump -p`。如果改成混杂模式后恢复，记录现象并检查过滤配置；不要把改变后的结果误认为此前数据面一直正常。

### 4.10 lan1 已收到包，协议栈有没有处理

先看报文内容：

- ARP request 的 target IP 是不是 `192.168.10.10`。
- ICMP request 的目的 MAC、目的 IP、长度和 checksum 是否正确。
- `lan1` 是否有正确 IP；若在 bridge / namespace / VLAN 上，实际 IP 落点是否与包路径一致。
- 同一子网是否被配置到多个接口，回程路由是否走错。

检查：

```sh
ip -br addr
ip -d link show lan1
ip route get 192.168.10.2
ip neigh show
sysctl net.ipv4.icmp_echo_ignore_all
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.lan1.rp_filter
nft list ruleset
iptables -S
tc filter show dev lan1 ingress
```

命令是否安装取决于系统。存在 bridge 时还查 bridge state、VLAN 和 bridge-family 过滤；存在 XDP / eBPF / namespace 时，按实际 attachment 和网络命名空间检查。

**这里需要区分“到协议栈”和“到应用层”：PC ping 板子时，板子的 ARP 应答与 ICMP echo reply 通常由内核生成，不要求板上有应用进程接收 request。** 因而本例正确检查终点是板子 ARP / IPv4 / ICMP 的处理和 reply 生成，而不是寻找某个板端 ping 服务。

若板子主动运行 `ping`，收到 echo reply 后才需要检查是否按 ID / sequence 交到 ping 使用的 socket。若后续测 TCP / UDP 应用，再继续查 socket、监听地址 / 端口、namespace 和用户态 `recv()`；不能用 ping 成功直接证明业务应用正常。

若需要函数级追踪，可根据该镜像已有符号和 tracepoint 沿 `arp_rcv()`、IPv4 接收、`ip_local_deliver()`、`icmp_rcv()` / echo reply 路径观察。先确认相关能力与实际符号，不给未知镜像照抄一个保证可用的探针脚本。

### 4.11 回包也要逐段证明

收到 request 不代表 reply 已经离开网线。反向证据链是：

```text
内核生成 ARP / ICMP reply
  → lan1 TX / DSA tagger
  → MTK MAC TX / TX DMA
  → RTL P6 RX
  → switch 转发
  → RTL P0 TX
  → PC 网卡 RX
  → PC 协议栈 / ping socket
```

| 断点 | 下一步 |
|---|---|
| request 到 lan1，不生成 reply | IP 落点、ARP / ICMP 策略、过滤、namespace |
| reply 在软件 TX 可见，DMA 未完成 | 队列、descriptor、DMA、MAC enable |
| MTK TX 有效，RTL P6 RX 无增长 | MTK → RTL 方向 RGMII、速率、delay、CPU ingress |
| P6 RX 增长，P0 TX 不增长 | tag 目的端口、isolation、VLAN、STP、过滤 |
| P0 TX 增长，PC 无有效 RX | 线端帧质量、PC 接收、CRC、错误 MAC / VLAN |
| PC 收到正确 reply，ping 无输出 | PC 过滤、socket、ID / sequence、源接口 |

软件 TX 统计不等于线端 TX 成功；确认驱动计数含义和 DMA 完成点，再归因下一段。

### 4.12 一张表判断当前卡在哪

| 观察结果 | 当前优先排查范围 |
|---|---|
| PC 未发 ARP | PC IP、路由、选错接口 |
| PC 发 ARP，P0 RX 无增长 | 外部 PHY、网线、端口映射 |
| P0 RX 增长，P6 TX 无增长 | RTL forwarding、CPU 配置、VLAN / STP |
| P6 TX 增长，MTK MAC RX 无增长 | CPU RGMII、MTK RX、CRC / 长度 / 过滤 |
| MTK MAC RX 增长，RX descriptor 不到 | FE / GDMA / DMA 路由与 ring |
| RX descriptor 到，未递交 skb | 来源 MAC、错误分支、buffer、XDP |
| skb 到 DSA，lan1 无有效包 | RTL tag、端口映射、错误硬件剥 tag |
| lan1 有 request，无 reply | 地址落点、协议栈策略、过滤 |
| reply 到 RTL P6 RX，P0 TX 无增长 | 反向转发、tag 目标、VLAN / STP |
| PC 收到正确 reply | 该测试报文的双向路径已成立 |

计数器名称和计数点必须先核实，背景流量、缓存刷新和间接读取也会影响结果。表中是定位边界，不能只凭一项累计值给出唯一根因。

### 4.13 最后做重复性验收

通过一次 ping 后，再验证：

```sh
# PC 端
ping -I enp3s0 -c 1000 192.168.10.10
ping -I enp3s0 -M do -s 1472 -c 100 192.168.10.10

# 板端
ping -I lan1 -c 1000 192.168.10.2
```

1472 字节 ICMP payload 加 IPv4 / ICMP 头为 1500 字节，用来覆盖普通 MTU；CPU tag 的额外长度应由相应数据路径正确处理。

继续做完全断电冷启动、热重启、网线拔插和所有已声明用户口的端口映射测试。比较 FCS / symbol / discard 等错误增量，不应随测试持续异常增长。

交付保存以下证据：

```text
kernel / DTB / modules 版本与配置
DTS / MAC / driver 补丁
probe、detect、setup、link-up 阶段日志
chip ID / version 与 CPU / MAC 配置读回
P0 RX/TX、P6 RX/TX、MTK MAC / DMA 的增量
PC、conduit、用户口的 ARP / ICMP 抓包
冷启动、拔插和双向大小包结果
未覆盖项和回退方式
```

本次文档没有进行样机或 Windows 实机验证；Windows PC 的互通应在实际 PC 上验证，不创建或使用 Win11 测试虚拟机。

### 4.14 常见现象与定位方向

#### 外部两个端口互通，开发板不通

外部口的硬件转发可能完全不经过 CPU，只能说明部分用户 PHY 和交换路径有效。优先检查 CPU mask、CPU tag、P6、RGMII、MTK MAC 与 DSA，不因外部口互通就跳过 CPU 数据通道。

#### ARP 能通，单播 ICMP 不通

ARP request 通常是广播，ICMP request 通常是单播。检查已知单播转发、FDB、目的 MAC、MAC 接收过滤、ICMP 策略和 checksum。广播通不能证明单播路径同样正确。

#### 只有一个方向正常

先标明真实方向：RTL → MTK，还是 MTK → RTL。前者对应 P6 TX / MTK RX，后者对应 MTK TX / P6 RX。分别检查该方向的时钟、数据、control、delay 与错误计数，不同时随机更改两个方向。

#### 加静态 ARP 后能 Ping

重点检查 ARP 广播、ARP reply、邻居学习和 IP/接口落点。静态 ARP 是定位实验；没有恢复正常动态 ARP 前，不视为完整验收。

#### 小包通，大包不通

核对 CPU 链路插入 8-byte tag 后的实际帧长、MAC/switch 长度限制、FCS、DMA 上报长度、MTU 和 checksum/offload。抓到大包从软件发送，不表示硬件接受并完整发出。

#### 冷启动不通，重启后通

从完全断电开始看供电、reset、参考时钟、首轮 MDIO 访问和初始化顺序。排除 bootloader 残留配置，以及 Linux setup 后的再次 reset。不能依靠“先手工初始化一次”完成验收。

#### 开启混杂模式后才通

记录开启前后变化，检查 MTK 地址过滤、DSA 用户地址同步以及广播/组播接收。手工开启不能替代正确的自动配置；抓包也可能因混杂模式改变现象，因此首先使用不主动开启混杂模式的抓包方式。

#### 关掉 Offload 后才通

先保存 `ethtool -k eth1`。针对 checksum、VLAN strip、GRO/GSO 等能力逐项做对照，并检查命令是否成功、特性是否为 fixed。随后修复相关 parser、能力声明或数据处理路径，再恢复可用卸载；不要把所有特性永久关闭当成根因说明。

### 4.15 实际要读懂的驱动职责

无需跳转其他文件才能使用本文；关键职责已经写在对应步骤中。下面用于在自己的工程中设置日志和断点：

| 组件 | 关键函数/入口 | 应证明什么 |
|---|---|---|
| MTK MDIO | `mtk_mdio_init()` | bus 注册、MDC 分频、read/write 可用 |
| Realtek transport | `realtek_mdio_probe()`、间接 read/write | 管理设备、复位、间接事务、返回值 |
| 芯片识别 | `rtl8365mb_get_chip_id_and_ver()`、`rtl8365mb_detect()` | magic、ID/version、正确型号映射 |
| 芯片初始化 | `rtl8365mb_reset_chip()`、`rtl8365mb_switch_init()`、`rtl8365mb_setup()` | reset、jam、CPU/端口配置与成功返回 |
| RTL CPU 数据接口 | `rtl8365mb_ext_config_rgmii()`、`rtl8365mb_ext_config_forcemode()` | P6/EXT1、delay、1000/full、link |
| MTK MAC | `mtk_mac_config()`、`mtk_mac_link_up()` | GMAC1 路径、速度、双工、收发使能 |
| MTK RX | `mtk_poll_rx()`、`napi_gro_receive()` | descriptor → skb → 网络接收路径 |
| Realtek DSA tagger | `rtl8_4_tag_rcv()` | 校验 8-byte tag、P0 → lan1、递交 |
| RTL 硬件统计 | `rtl8365mb_mib_counter_read()` | 按真实 port 和计数器读取，保护间接事务 |
| Linux 协议栈 | ARP、IPv4、ICMP 接收与应答 | 本机地址识别、过滤、reply 生成与回程 |

具体板级参数仍须按所持 MT7622 TRM、RTL8365MB-VC datasheet/programming manual/errata 核对。本文没有获得用户实际原理图和配套手册，也没有进行样机实测；不能把示例 GPIO、管理地址和 delay 当作已经在目标硬件上验证的结果。
