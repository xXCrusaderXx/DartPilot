#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

#include "pattern_image_provider.hpp"

int main (int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("DartPilot Setup");
    QGuiApplication::setDesktopFileName("dartpilot-setup");
    QGuiApplication::setWindowIcon(QIcon(":/qt/qml/DartPilotSetup/icons/dartpilot.svg"));
    QQuickStyle::setStyle("Material");

    QCommandLineParser parser;
    parser.setApplicationDescription("DartPilot camera setup and diagnostics");
    parser.addHelpOption();
    const QCommandLineOption page_option("page", "Page shown at start: 0 cameras, 1 intrinsic, 2 extrinsic.", "index", "0");
    // For documentation and for checking the layout without a display, e.g. with QT_QPA_PLATFORM=offscreen
    const QCommandLineOption screenshot_option("screenshot", "Save the window as an image after --delay milliseconds and quit.", "file");
    const QCommandLineOption delay_option("delay", "Delay before --screenshot, in milliseconds.", "ms", "3000");
    parser.addOptions({page_option, screenshot_option, delay_option});
    parser.process(app);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    // The engine takes ownership of the provider.
    engine.addImageProvider("charuco", new dartpilot::setup::PatternImageProvider);
    engine.setInitialProperties({{"initialPage", parser.value(page_option).toInt()}});
    engine.loadFromModule("DartPilotSetup", "Main");

    if(parser.isSet(screenshot_option) && !engine.rootObjects().isEmpty())
    {
        auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().constFirst());
        const QString file = parser.value(screenshot_option);
        QTimer::singleShot(parser.value(delay_option).toInt(), &app,
                           [window, file]
                           {
                               const bool saved = window && window->grabWindow().save(file);
                               QCoreApplication::exit(saved ? 0 : 1);
                           });
    }
    return app.exec();
}
