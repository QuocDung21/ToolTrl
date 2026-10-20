import SwiftUI
import WebKit
import AppKit

public enum ApexChartStyle: String {
    case bar = "bar"
    case area = "area"
    case donut = "donut"
}

public struct ApexChartSeriesItem: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let value: Double
    public let colorHex: String?
    
    public init(name: String, value: Double, colorHex: String? = nil) {
        self.name = name
        self.value = value
        self.colorHex = colorHex
    }
}

public struct ApexChartView: NSViewRepresentable {
    public let chartStyle: ApexChartStyle
    public let categories: [String]
    public let values: [Double]
    public let donutItems: [ApexChartSeriesItem]
    public let goalValue: Double?
    public let yTitle: String
    public let isDarkMode: Bool
    
    public init(
        chartStyle: ApexChartStyle,
        categories: [String] = [],
        values: [Double] = [],
        donutItems: [ApexChartSeriesItem] = [],
        goalValue: Double? = nil,
        yTitle: String = "Số lượng",
        isDarkMode: Bool = true
    ) {
        self.chartStyle = chartStyle
        self.categories = categories
        self.values = values
        self.donutItems = donutItems
        self.goalValue = goalValue
        self.yTitle = yTitle
        self.isDarkMode = isDarkMode
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        webView.autoresizingMask = [.width, .height]
        webView.wantsLayer = true
        webView.layer?.drawsAsynchronously = true
        
        context.coordinator.webView = webView
        context.coordinator.loadChartHTML(
            webView: webView,
            chartStyle: chartStyle,
            categories: categories,
            values: values,
            donutItems: donutItems,
            goalValue: goalValue,
            yTitle: yTitle,
            isDarkMode: isDarkMode
        )
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.updateChart(
            webView: webView,
            chartStyle: chartStyle,
            categories: categories,
            values: values,
            donutItems: donutItems,
            goalValue: goalValue,
            yTitle: yTitle,
            isDarkMode: isDarkMode
        )
    }

    public final class Coordinator {
        weak var webView: WKWebView?
        private var isLoaded = false
        private var lastStyle: ApexChartStyle?
        private var lastDarkMode: Bool?
        private var lastCategories: [String] = []
        private var lastValues: [Double] = []
        private var lastDonutValues: [Double] = []
        
        func loadChartHTML(
            webView: WKWebView,
            chartStyle: ApexChartStyle,
            categories: [String],
            values: [Double],
            donutItems: [ApexChartSeriesItem],
            goalValue: Double?,
            yTitle: String,
            isDarkMode: Bool
        ) {
            self.lastStyle = chartStyle
            self.lastDarkMode = isDarkMode
            self.lastCategories = categories
            self.lastValues = values
            self.lastDonutValues = donutItems.map { $0.value }
            
            let scriptContent = loadApexChartsScript()
            let html = buildHTML(
                scriptSource: scriptContent,
                chartStyle: chartStyle,
                categories: categories,
                values: values,
                donutItems: donutItems,
                goalValue: goalValue,
                yTitle: yTitle,
                isDarkMode: isDarkMode
            )
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            isLoaded = true
        }
        
        func updateChart(
            webView: WKWebView,
            chartStyle: ApexChartStyle,
            categories: [String],
            values: [Double],
            donutItems: [ApexChartSeriesItem],
            goalValue: Double?,
            yTitle: String,
            isDarkMode: Bool
        ) {
            if lastStyle != chartStyle || lastDarkMode != isDarkMode {
                loadChartHTML(
                    webView: webView,
                    chartStyle: chartStyle,
                    categories: categories,
                    values: values,
                    donutItems: donutItems,
                    goalValue: goalValue,
                    yTitle: yTitle,
                    isDarkMode: isDarkMode
                )
                return
            }
            
            if chartStyle == .donut {
                let seriesArray = donutItems.map { $0.value }
                let labelsArray = donutItems.map { $0.name }
                
                // Do not re-evaluate JS if data did not change (e.g. sidebar toggle / resize)
                if seriesArray == lastDonutValues {
                    return
                }
                self.lastDonutValues = seriesArray
                
                let js = """
                if (window.chart) {
                    window.chart.updateOptions({
                        labels: \(jsonString(labelsArray))
                    }, false, false);
                    window.chart.updateSeries(\(jsonString(seriesArray)), true);
                }
                """
                webView.evaluateJavaScript(js, completionHandler: nil)
            } else {
                // Do not re-evaluate JS if data did not change (e.g. sidebar toggle / resize)
                if categories == lastCategories && values == lastValues {
                    return
                }
                self.lastCategories = categories
                self.lastValues = values
                
                let js = """
                if (window.chart) {
                    window.chart.updateOptions({
                        xaxis: { categories: \(jsonString(categories)) }
                    }, false, false);
                    window.chart.updateSeries([{
                        name: '\(yTitle)',
                        data: \(jsonString(values))
                    }], true);
                }
                """
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
        
        private func loadApexChartsScript() -> String {
            // Bundled copy (Scripts/build_app.sh puts it in Contents/Resources).
            if let bundleURL = Bundle.main.url(forResource: "apexcharts.min", withExtension: "js"),
               let content = try? String(contentsOf: bundleURL, encoding: .utf8) {
                return content
            }
            // Empty result makes the caller fall back to the pinned CDN build,
            // so the chart still renders in a bare `swift run` without the bundle.
            return ""
        }
        
        private func jsonString<T: Encodable>(_ value: T) -> String {
            guard let data = try? JSONEncoder().encode(value),
                  let str = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return str
        }
        
        private func buildHTML(
            scriptSource: String,
            chartStyle: ApexChartStyle,
            categories: [String],
            values: [Double],
            donutItems: [ApexChartSeriesItem],
            goalValue: Double?,
            yTitle: String,
            isDarkMode: Bool
        ) -> String {
            let scriptTag: String
            if !scriptSource.isEmpty {
                scriptTag = "<script>\(scriptSource)</script>"
            } else {
                scriptTag = "<script src=\"https://cdn.jsdelivr.net/npm/apexcharts@3.52.0/dist/apexcharts.min.js\"></script>"
            }
            
            let chartConfigJS: String
            let themeMode = isDarkMode ? "dark" : "light"
            let textColor = isDarkMode ? "#94A3B8" : "#64748B"
            let gridColor = isDarkMode ? "rgba(255, 255, 255, 0.06)" : "rgba(0, 0, 0, 0.06)"
            
            if chartStyle == .donut {
                let series = donutItems.map { $0.value }
                let labels = donutItems.map { $0.name }
                let colors = donutItems.compactMap { $0.colorHex }.isEmpty
                    ? "['#007AFF', '#AF52DE', '#30B0C7', '#FF9500', '#FF2D55', '#5856D6', '#34C759', '#32ADE6']"
                    : jsonString(donutItems.compactMap { $0.colorHex })
                
                chartConfigJS = """
                var options = {
                    series: \(jsonString(series)),
                    labels: \(jsonString(labels)),
                    chart: {
                        type: 'donut',
                        height: '100%',
                        background: 'transparent',
                        redrawOnWindowResize: false,
                        redrawOnParentResize: false,
                        animations: {
                            enabled: true,
                            easing: 'easeinout',
                            speed: 600,
                            animateGradually: { enabled: true, delay: 100 },
                            dynamicAnimation: { enabled: false }
                        }
                    },
                    colors: \(colors),
                    stroke: {
                        show: true,
                        width: 2,
                        colors: [\(isDarkMode ? "'#1E2330'" : "'#FFFFFF'")]
                    },
                    plotOptions: {
                        pie: {
                            donut: {
                                size: '68%',
                                labels: {
                                    show: true,
                                    name: {
                                        show: true,
                                        fontSize: '11px',
                                        color: '\(textColor)',
                                        offsetY: -3
                                    },
                                    value: {
                                        show: true,
                                        fontSize: '17px',
                                        fontWeight: 700,
                                        color: '\(isDarkMode ? "#F8FAFC" : "#0F172A")',
                                        offsetY: 4
                                    },
                                    total: {
                                        show: true,
                                        label: 'Đã lưu',
                                        fontSize: '10.5px',
                                        color: '\(textColor)'
                                    }
                                }
                            }
                        }
                    },
                    dataLabels: { enabled: false },
                    legend: { show: false },
                    tooltip: {
                        theme: '\(themeMode)',
                        y: { formatter: function(val) { return val + " từ"; } }
                    }
                };
                """
            } else if chartStyle == .bar {
                let maxVal = max(values.max() ?? 0, goalValue ?? 0)
                let yMax = maxVal > 0 ? ceil(maxVal * 1.15) : 10
                let showLabels = values.count <= 7
                
                var annotationsJS = ""
                if let goal = goalValue, goal > 0 {
                    annotationsJS = """
                    annotations: {
                        yaxis: [{
                            y: \(goal),
                            borderColor: '#FF9500',
                            strokeDashArray: 4,
                            borderWidth: 1.5,
                            label: {
                                borderColor: '#FF9500',
                                style: {
                                    color: '#fff',
                                    background: '#FF9500',
                                    fontSize: '9.5px',
                                    fontWeight: 700
                                },
                                text: 'Mục tiêu: \(Int(goal))'
                            }
                        }]
                    },
                    """
                }
                
                chartConfigJS = """
                var options = {
                    series: [{
                        name: '\(yTitle)',
                        data: \(jsonString(values))
                    }],
                    chart: {
                        type: 'bar',
                        height: '100%',
                        background: 'transparent',
                        toolbar: { show: false },
                        redrawOnWindowResize: false,
                        redrawOnParentResize: false,
                        animations: {
                            enabled: true,
                            easing: 'easeinout',
                            speed: 600,
                            animateGradually: { enabled: true, delay: 80 },
                            dynamicAnimation: { enabled: false }
                        }
                    },
                    \(annotationsJS)
                    plotOptions: {
                        bar: {
                            borderRadius: 6,
                            borderRadiusApplication: 'end',
                            columnWidth: '\(values.count <= 7 ? "38%" : (values.count > 15 ? "65%" : "48%"))',
                            distributed: false,
                            dataLabels: { position: 'top' }
                        }
                    },
                    colors: ['#007AFF'],
                    fill: {
                        type: 'gradient',
                        gradient: {
                            shade: 'light',
                            type: "vertical",
                            shadeIntensity: 0.25,
                            gradientToColors: ['#00C6FF'],
                            inverseColors: false,
                            opacityFrom: 0.95,
                            opacityTo: 0.65,
                            stops: [0, 100]
                        }
                    },
                    dataLabels: {
                        enabled: \(showLabels),
                        formatter: function (val) { return val > 0 ? Math.round(val) : ""; },
                        offsetY: -18,
                        style: {
                            fontSize: '10px',
                            fontWeight: 600,
                            colors: ['\(textColor)']
                        }
                    },
                    grid: {
                        borderColor: '\(gridColor)',
                        strokeDashArray: 3,
                        padding: { top: 6, right: 12, bottom: 0, left: 12 }
                    },
                    xaxis: {
                        categories: \(jsonString(categories)),
                        labels: {
                            style: {
                                colors: '\(textColor)',
                                fontSize: '10.5px',
                                fontFamily: '-apple-system, sans-serif'
                            }
                        },
                        axisBorder: { show: false },
                        axisTicks: { show: false }
                    },
                    yaxis: {
                        min: 0,
                        max: \(yMax),
                        forceNiceScale: true,
                        labels: {
                            formatter: function (val) { return Math.round(val); },
                            style: {
                                colors: '\(textColor)',
                                fontSize: '10px',
                                fontFamily: 'SF Mono, monospace'
                            }
                        }
                    },
                    tooltip: {
                        theme: '\(themeMode)',
                        x: { show: true },
                        y: { formatter: function(val) { return Math.round(val) + " " + '\(yTitle.lowercased())'; } }
                    }
                };
                """
            } else {
                // Smooth Spline Area Chart
                chartConfigJS = """
                var options = {
                    series: [{
                        name: '\(yTitle)',
                        data: \(jsonString(values))
                    }],
                    chart: {
                        type: 'area',
                        height: '100%',
                        background: 'transparent',
                        toolbar: { show: false },
                        redrawOnWindowResize: false,
                        redrawOnParentResize: false,
                        animations: {
                            enabled: true,
                            easing: 'easeinout',
                            speed: 600,
                            dynamicAnimation: { enabled: false }
                        }
                    },
                    colors: ['#007AFF'],
                    stroke: {
                        curve: 'smooth',
                        width: 2.5
                    },
                    fill: {
                        type: 'gradient',
                        gradient: {
                            shadeIntensity: 1,
                            opacityFrom: 0.45,
                            opacityTo: 0.04,
                            stops: [0, 95, 100]
                        }
                    },
                    markers: {
                        size: 0,
                        colors: ['#007AFF'],
                        strokeColors: '#fff',
                        strokeWidth: 2,
                        hover: { size: 6 }
                    },
                    grid: {
                        borderColor: '\(gridColor)',
                        strokeDashArray: 3,
                        padding: { top: 6, right: 12, bottom: 0, left: 12 }
                    },
                    xaxis: {
                        categories: \(jsonString(categories)),
                        labels: {
                            style: {
                                colors: '\(textColor)',
                                fontSize: '10.5px',
                                fontFamily: '-apple-system, sans-serif'
                            }
                        },
                        axisBorder: { show: false },
                        axisTicks: { show: false }
                    },
                    yaxis: {
                        min: 0,
                        forceNiceScale: true,
                        labels: {
                            formatter: function (val) { return Math.round(val); },
                            style: {
                                colors: '\(textColor)',
                                fontSize: '10px',
                                fontFamily: 'SF Mono, monospace'
                            }
                        }
                    },
                    tooltip: {
                        theme: '\(themeMode)',
                        x: { show: true },
                        y: { formatter: function(val) { return Math.round(val) + " " + '\(yTitle.lowercased())'; } }
                    }
                };
                """
            }

            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
                <style>
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    html, body {
                        width: 100%;
                        height: 100%;
                        background-color: transparent !important;
                        overflow: hidden;
                        user-select: none;
                        -webkit-user-select: none;
                        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
                    }
                    #chart {
                        width: 100%;
                        height: 100%;
                    }
                    .apexcharts-canvas {
                        background: transparent !important;
                    }
                    .apexcharts-tooltip {
                        border-radius: 8px !important;
                        box-shadow: 0 4px 16px rgba(0,0,0,0.25) !important;
                        border: 1px solid \(isDarkMode ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.08)") !important;
                    }
                </style>
                \(scriptTag)
            </head>
            <body>
                <div id="chart"></div>
                <script>
                    \(chartConfigJS)
                    var chart = new ApexCharts(document.querySelector("#chart"), options);
                    chart.render();
                    window.chart = chart;

                    // Smooth Debounced Resize: Never redraw during active window/sidebar animations
                    var resizeTimer = null;
                    window.addEventListener('resize', function() {
                        clearTimeout(resizeTimer);
                        resizeTimer = setTimeout(function() {
                            if (window.chart) {
                                if (typeof window.chart.windowResize === 'function') {
                                    window.chart.windowResize();
                                } else if (typeof window.chart.updateOptions === 'function') {
                                    window.chart.updateOptions({}, false, false);
                                }
                            }
                        }, 150);
                    });
                </script>
            </body>
            </html>
            """
        }
    }
}
