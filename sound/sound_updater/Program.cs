// VIC sound updater
// -----------------
//
// - Check for .json files in selected folder
// - Parse .json file for sound definitions and trigger indexes
// - Get WAV file lengths and CRCs from ZIP
// - Copy .zip to verilator folder
// - Update MRA rom index=2 with file names and crcs 
// - Update MRA rom index=3 with file position and trigger metadata

using Newtonsoft.Json;
using sound_updater;
using System.IO.Compression;
using System.Text;
using System.Xml;

const string data_path = @"C:\repos\Arcade-SegaVICZ80_MiSTer\sound\";
const string mra_path = @"C:\repos\Arcade-SegaVICZ80_MiSTer\releases\";
const string verilator_path = @"C:\repos\Arcade-SegaVICZ80_MiSTer\verilator\roms\sound\";

int maxSounds = 0;

foreach (string data_file in Directory.GetFiles(data_path, "*.json"))
{
	var file_text = File.ReadAllText(data_file);
	var set = JsonConvert.DeserializeObject<SoundSet>(file_text);

	// Check zip exists
	var zipPath = data_path + set.ZipName;
	if (!File.Exists(zipPath))
	{
		Console.WriteLine($"ERROR: Cannot find zip = {set.ZipName}");
		continue;
	}

	Console.WriteLine($"Reading zip = {zipPath}");
	var zip = ZipFile.OpenRead(zipPath);

	foreach (var entry in zip.Entries)
	{
		foreach (Sound sound in set.Sounds.Where(x => x.Name == entry.Name))
		{
			if (sound == null)
			{
				Console.WriteLine($"ERROR: {entry.Name}");
			}
			else
			{
				Console.WriteLine($"{entry.FullName} - {entry.Crc32:x8}");
				sound.Length = entry.Length;
				sound.CRC = entry.Crc32.ToString("x8");
			}
		}
	}

	// Loop and update through all applicable MRAs
	foreach (string MRAName in set.AppliesTo)
	{
		var mraPath = $"{mra_path}{MRAName}.mra";
		Console.WriteLine($"Reading MRA = {mraPath}");
		var mra_text = File.ReadAllText(mraPath);
		XmlDocument mra = new();
		mra.LoadXml(mra_text);

		// Find / create rom index=2
		XmlElement romNode_wav = (XmlElement)FindOrCreateNode(mra, "rom", "index", "2");
		//romNode_wav.SetAttribute("zip", $"/sound/{set.ZipName}");
		// Remove existing contents
		while (romNode_wav.ChildNodes.Count > 0) { _ = romNode_wav.RemoveChild(romNode_wav.ChildNodes[0]); }


		maxSounds = Math.Max(maxSounds, set.Sounds.Length);

		// Add wave files and CRCs
		foreach (Sound wav in set.Sounds)
		{
			XmlElement wavNode = mra.CreateElement("part");
			//wavNode.SetAttribute("crc", wav.CRC);
			//wavNode.SetAttribute("name", wav.Name);


			byte[] byteData = File.ReadAllBytes(data_path + "/" + set.AppliesTo[0] + "/" + wav.Name);
			StringBuilder data = new StringBuilder();
			data.Append("\r\n\t\t\t");
			int l = 0;
			foreach (byte b in byteData)
			{
				data.Append(b.ToString("X2") + " ");
				l++;
				if (l == 16)
				{
					data.Append("\r\n\t\t\t");
					l = 0;
				}
			}
			data.Append("\r\n\t");
			wavNode.InnerText = data.ToString();

			romNode_wav.AppendChild(wavNode);
		}

		// Find / create rom index=3
		XmlNode romNode_meta = FindOrCreateNode(mra, "rom", "index", "3");
		// Remove existing contents
		while (romNode_meta.ChildNodes.Count > 0) { _ = romNode_meta.RemoveChild(romNode_meta.ChildNodes[0]); }
		// Add wave offsets and triggers
		XmlElement partNode_meta = mra.CreateElement("part");
		romNode_meta.AppendChild(partNode_meta);
		string meta = "\r\n\t\t";
		long p = 0;
		foreach (Sound wav in set.Sounds)
		{
			byte p4 = (byte)(p >> 24);
			byte p3 = (byte)(p >> 16);
			byte p2 = (byte)(p >> 8);
			byte p1 = (byte)p;
			byte t = (byte)wav.Trigger;
			byte o = 0; // Play on high by default
			if (wav.TriggerMode == "playWhenHigh") { o = 1; };
			if (wav.TriggerMode == "loopOnHigh") { o = 2; };
			if (wav.TriggerMode == "loopWhenHigh") { o = 3; };
			meta += $"\t{p4:X2} {p3:X2} {p2:X2} {p1:X2} {t:X2} {o:X2} 00 00 \r\n\t\t";
			p += wav.Length;
		}
		XmlNode text_meta = mra.CreateTextNode(meta);
		partNode_meta.AppendChild(text_meta);

		Console.WriteLine("E: " + JsonConvert.SerializeObject(romNode_meta));

		// Save updated MRA
		mra.Save(mraPath);

		// Fix dem tabs
		File.WriteAllText(mraPath, File.ReadAllText(mraPath).Replace("  ", "\t"));

		// Copy zip to target
		var verilatorZipPath = verilator_path + set.ZipName;
		File.Copy(zipPath, verilatorZipPath, true);

		Console.WriteLine("Max sounds: " + maxSounds);
	}
}

static XmlNode FindOrCreateNode(XmlDocument doc, string name, string attName, string attValue)
{
	var nodes = doc.FirstChild.SelectNodes($"//{name}[@{attName}='{attValue}']");
	XmlElement node = null;
	if (nodes.Count == 0)
	{
		node = (XmlElement)doc.CreateNode(XmlNodeType.Element, name, null);
		node.SetAttribute(attName, attValue);
		doc.FirstChild.AppendChild(node);
	}
	else
	{
		node = (XmlElement)nodes[0];
	}
	return node;
}