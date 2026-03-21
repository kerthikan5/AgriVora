import asyncio
from bleak import BleakScanner, BleakClient

MAC_ADDRESS = "70:4B:CA:8D:A7:86"
UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"

async def main():
    print("Scanning...")
    devices = await BleakScanner.discover(timeout=5.0)
    for d in devices:
        print(d.address, d.name)
    
    device = await BleakScanner.find_device_by_address(MAC_ADDRESS, timeout=10.0)
    if not device:
        print(f"Could not find device with address {MAC_ADDRESS}")
        return
    
    print(f"Found {device.name} at {device.address}")
    
    try:
        async with BleakClient(device) as client:
            print(f"Connected: {client.is_connected}")
            services = await client.get_services()
            print("Services:")
            for service in services:
                print(service)
                for char in service.characteristics:
                    print(f"  - Char: {char.uuid}, Properties: {char.properties}")
                    if "read" in char.properties:
                        try:
                            val = await client.read_gatt_char(char.uuid)
                            print(f"    Value: {val}")
                        except Exception as e:
                            print(f"    Failed to read: {e}")
            
            try:
                data = await client.read_gatt_char(UUID)
                print(f"Target UUID {UUID} value: {data}")
            except Exception as e:
                print(f"Error reading target UUID: {e}")
    except Exception as e:
        print(f"Connection failed: {e}")

if __name__ == "__main__":
    asyncio.run(main())
