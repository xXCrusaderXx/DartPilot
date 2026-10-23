#include <gtest/gtest.h>

#include "dartpilot/capture/v4l2_device.hpp"

TEST(UsbPortFromPath, ReadsThePortChain)
{
    EXPECT_EQ(dartpilot::capture::usbPortFromPath("pci-0000:0e:00.4-usb-0:2.4.3.1.2:1.0-video-index0"), "2.4.3.1.2");
    EXPECT_EQ(dartpilot::capture::usbPortFromPath("/dev/v4l/by-path/pci-0000:0e:00.4-usbv2-0:3:1.0-video-index0"), "3");
}

TEST(UsbPortFromPath, EmptyWithoutUsb)
{
    EXPECT_EQ(dartpilot::capture::usbPortFromPath("platform-fe801000.csi-video-index0"), "");
    EXPECT_EQ(dartpilot::capture::usbPortFromPath("pci-0000:0e:00.4-usb-0"), "");
}

TEST(MetadataPathFor, ReplacesTheImageNodeIndex)
{
    EXPECT_EQ(dartpilot::capture::metadataPathFor("/dev/v4l/by-path/pci-0000:0e:00.4-usb-0:2.4.3.1.2:1.0-video-index0"),
              "/dev/v4l/by-path/pci-0000:0e:00.4-usb-0:2.4.3.1.2:1.0-video-index1");
}

TEST(MetadataPathFor, EmptyForOtherNodes)
{
    EXPECT_EQ(dartpilot::capture::metadataPathFor("/dev/v4l/by-path/pci-0000:0e:00.4-usb-0:2.4.3.1.2:1.0-video-index1"), "");
    EXPECT_EQ(dartpilot::capture::metadataPathFor("/dev/video0"), "");
}
