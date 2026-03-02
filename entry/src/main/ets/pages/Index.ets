import { webview } from '@kit.ArkWeb';
import { WebnatViewModel } from './WebnatViewModel';
import { LogEntry, LogType, LogCategory } from './LogEntry';

/**
 * 主页面 - 包含 Web 界面和原生界面两个 Tab
 */
@Entry
@ComponentV2
struct Index {
  @Local currentTabIndex: number = 0;
  @Local viewModel: WebnatViewModel = new WebnatViewModel();
  webController: webview.WebviewController = new webview.WebviewController();
  
  // Web 页面 URL - 需要根据实际情况调整
  private webUrl: string = 'http://172.16.71.254:5173/';

  aboutToAppear(): void {
    // 设置 WebView Controller 并初始化 Webnat
  }

  aboutToDisappear(): void {
    // 清理资源
    this.viewModel.cleanup();
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.Start, index: this.currentTabIndex }) {
        // 第一个 Tab: Web 界面
        TabContent() {
          this.WebTabView()
        }
        .tabBar('Web')

        // 第二个 Tab: 原生界面
        TabContent() {
          this.NativeTabView()
        }
        .tabBar('原生')
      }
      .onChange((index: number) => {
        this.currentTabIndex = index;
      })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  /**
   * Web 界面 Tab
   */
  @Builder
  WebTabView() {
    Column() {
      Web({ src: this.webUrl, controller: this.webController })
        .width('100%')
        .height('100%')
        .onPageBegin(() => {
          console.info('WebView page begin');
        })
        .onPageEnd(() => {
          console.info('WebView page end');
        })
        .onErrorReceive((event) => {
          console.error('WebView error: ' + JSON.stringify(event));
          this.viewModel.addLog(LogType.ERROR, LogCategory.SYSTEM, `WebView 加载错误: ${event}`);
        }).onControllerAttached(()=>{
          this.viewModel.setup(this.webController);
      })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 原生界面 Tab
   */
  @Builder
  NativeTabView() {
    Column() {
      // 控制面板
      Column() {
        Row() {
          Text('Native 控制面板')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(`连接数: ${this.viewModel.connectionCount}`)
            .fontSize(12)
            .fontColor('#999999')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Row() {
          Button('发送 Raw')
            .type(ButtonType.Normal)
            .backgroundColor('#4CAF50')
            .fontColor(Color.White)
            .onClick(() => {
              this.viewModel.sendRaw();
            })
            .layoutWeight(1)
            .margin({ right: 6 })

          Button('发送 Broadcast')
            .type(ButtonType.Normal)
            .backgroundColor('#2196F3')
            .fontColor(Color.White)
            .onClick(() => {
              this.viewModel.sendBroadcast();
            })
            .layoutWeight(1)
            .margin({ left: 6, right: 6 })

          Button('发送 Method')
            .type(ButtonType.Normal)
            .backgroundColor('#FF9800')
            .fontColor(Color.White)
            .onClick(() => {
              this.viewModel.sendMethod();
            })
            .layoutWeight(1)
            .margin({ left: 6 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })

        Row() {
          Button('清空日志')
            .type(ButtonType.Normal)
            .fontSize(12)
            .backgroundColor('#E0E0E0')
            .fontColor('#333333')
            .onClick(() => {
              this.viewModel.clearLogs();
            })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')

      Divider()
        .color('#E0E0E0')

      // 日志显示区域
      List() {
        ForEach(this.viewModel.logs, (log: LogEntry) => {
          this.LogRowView(log)
        }, (log: LogEntry) => log.id)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 日志行视图
   */
  @Builder
  LogRowView(log: LogEntry) {
    Row() {
      Text(log.time)
        .fontSize(11)
        .fontFamily('monospace')
        .fontColor('#999999')
        .width(80)

      Text(log.type)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(4)
        .backgroundColor(this.getTypeColor(log.type))

      Text(`${log.category}: ${log.message}`)
        .fontSize(12)
        .fontFamily('monospace')
        .fontColor('#333333')
        .layoutWeight(1)
        .maxLines(10)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(8)
    .backgroundColor(this.getTypeBackgroundColor(log.type))
    .borderRadius(6)
    .border({
      width: 2,
      color: this.getTypeColor(log.type),
      style: BorderStyle.Solid
    })
    .margin({ left: 8, right: 8, top: 4, bottom: 4 })
  }

  /**
   * 获取日志类型对应的颜色
   */
  private getTypeColor(type: LogType): ResourceColor {
    switch (type) {
      case LogType.SENT:
        return '#4CAF50';
      case LogType.RECEIVED:
        return '#2196F3';
      case LogType.ERROR:
        return '#F44336';
      default:
        return '#999999';
    }
  }

  /**
   * 获取日志类型对应的背景颜色
   */
  private getTypeBackgroundColor(type: LogType): ResourceColor {
    switch (type) {
      case LogType.SENT:
        return '#E8F5E9';
      case LogType.RECEIVED:
        return '#E3F2FD';
      case LogType.ERROR:
        return '#FFEBEE';
      default:
        return '#FFFFFF';
    }
  }
}