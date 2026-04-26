import Quickshell
import Quickshell.Io
import QtQuick

TYPE99MQS_Quickshell99NScope99TYPE {
  id: root

  // add a property in the root
  property string time

  TYPE99MQS_Quickshell99NVariants99TYPE {
    model: Quickshell.screens

    delegate: TYPE99MQT_qml_QtQml99NComponent99TYPE {
      TYPE99MQS_Quickshell99NPanelWindow99TYPE {
        required property var modelData
        screen: modelData

        anchors {
          top: true
          left: true
          right: true
        }

        implicitHeight: 30

        TYPE99MQT_qml_QtQuick99NText99TYPE {
          // remove the id as we don't need it anymore

          anchors.centerIn: parent

          // bind the text to the root object's time property
          text: root.time
        }
      }
    }
  }

  TYPE99MQS_Quickshell_Io99NProcess99TYPE {
    id: dateProc
    command: ["date"]
    running: true

    stdout: TYPE99MQS_Quickshell_Io99NStdioCollector99TYPE {
      // update the property instead of the clock directly
      onStreamFinished: root.time = this.text
    }
  }

  TYPE99MQT_qml_QtQml99NTimer99TYPE {
    interval: 1000
    running: true
    repeat: true
    onTriggered: dateProc.running = true
  }
}
