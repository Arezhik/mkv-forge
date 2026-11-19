import Foundation

// `mkvmerge -J` output captured from MKVToolNix 103.0 (schema 20) and 82.0 (schema 19)
// on small generated files (Phase 2 research). File names are the generated ones.
// `cannotOpen` is a missing file (exit 2). The others exited 0.
enum IdentifyFixtures {
    static let full103 = #"""
{
 "attachments": [
  {
   "content_type": "font/ttf",
   "description": "",
   "file_name": "font.ttf",
   "id": 1,
   "properties": {
    "uid": 6404717964994204768
   },
   "size": 5
  }
 ],
 "chapters": [
  {
   "num_entries": 2
  }
 ],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3042000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "ed58621e32ae73e37feaa8d96a9b825f",
   "timestamp_scale": 1000000,
   "title": "Full Title",
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "full.mkv",
 "global_tags": [
  {
   "num_entries": 2
  }
 ],
 "identification_format_version": 20,
 "track_tags": [
  {
   "num_entries": 1,
   "track_id": 2
  }
 ],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "101117",
    "tag_duration": "00:00:03.000000000",
    "tag_number_of_bytes": "37919",
    "tag_number_of_frames": "72",
    "uid": 8418516832386299660
   },
   "type": "video"
  },
  {
   "codec": "AAC",
   "id": 1,
   "properties": {
    "audio_channels": 1,
    "audio_sampling_frequency": 44100,
    "codec_id": "A_AAC",
    "codec_private_data": "120856e500",
    "codec_private_length": 5,
    "default_duration": 23219954,
    "default_track": true,
    "enabled_track": true,
    "forced_track": false,
    "language": "jpn",
    "language_ietf": "ja",
    "minimum_timestamp": 0,
    "num_index_entries": 0,
    "number": 2,
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "69170",
    "tag_duration": "00:00:03.042000000",
    "tag_number_of_bytes": "26302",
    "tag_number_of_frames": "131",
    "track_name": "Main A",
    "uid": 6081720311881535317
   },
   "type": "audio"
  },
  {
   "codec": "Opus",
   "id": 2,
   "properties": {
    "audio_channels": 1,
    "audio_sampling_frequency": 48000,
    "codec_delay": 6500000,
    "codec_id": "A_OPUS",
    "codec_private_data": "4f707573486561640101380180bb0000000000",
    "codec_private_length": 19,
    "default_track": false,
    "enabled_track": true,
    "flag_commentary": true,
    "forced_track": false,
    "language": "eng",
    "language_ietf": "en",
    "minimum_timestamp": 0,
    "num_index_entries": 0,
    "number": 3,
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "77398",
    "tag_duration": "00:00:03.007000000",
    "tag_encoder": "Lavc61.19.101 libopus",
    "tag_number_of_bytes": "29092",
    "tag_number_of_frames": "151",
    "track_name": "Commentary",
    "uid": 2184537024976972723
   },
   "type": "audio"
  },
  {
   "codec": "SubRip/SRT",
   "id": 3,
   "properties": {
    "codec_id": "S_TEXT/UTF8",
    "codec_private_length": 0,
    "default_track": true,
    "enabled_track": true,
    "encoding": "UTF-8",
    "forced_track": true,
    "language": "eng",
    "language_ietf": "en",
    "minimum_timestamp": 500000000,
    "num_index_entries": 2,
    "number": 4,
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "34",
    "tag_duration": "00:00:02.300000000",
    "tag_number_of_bytes": "10",
    "tag_number_of_frames": "2",
    "text_subtitles": true,
    "track_name": "Signs",
    "uid": 17389891100597187705
   },
   "type": "subtitles"
  }
 ],
 "warnings": []
}
"""#

    static let full82 = #"""
{
 "attachments": [
  {
   "content_type": "font/ttf",
   "description": "",
   "file_name": "font.ttf",
   "id": 1,
   "properties": {
    "uid": 6404717964994204768
   },
   "size": 5
  }
 ],
 "chapters": [
  {
   "num_entries": 2
  }
 ],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3042000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "ed58621e32ae73e37feaa8d96a9b825f",
   "timestamp_scale": 1000000,
   "title": "Full Title",
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "full.mkv",
 "global_tags": [
  {
   "num_entries": 2
  }
 ],
 "identification_format_version": 19,
 "track_tags": [
  {
   "num_entries": 1,
   "track_id": 2
  }
 ],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "uid": 8418516832386299660
   },
   "type": "video"
  },
  {
   "codec": "AAC",
   "id": 1,
   "properties": {
    "audio_channels": 1,
    "audio_sampling_frequency": 44100,
    "codec_id": "A_AAC",
    "codec_private_data": "120856e500",
    "codec_private_length": 5,
    "default_duration": 23219954,
    "default_track": true,
    "enabled_track": true,
    "forced_track": false,
    "language": "jpn",
    "language_ietf": "ja",
    "minimum_timestamp": 0,
    "num_index_entries": 0,
    "number": 2,
    "track_name": "Main A",
    "uid": 6081720311881535317
   },
   "type": "audio"
  },
  {
   "codec": "Opus",
   "id": 2,
   "properties": {
    "audio_channels": 1,
    "audio_sampling_frequency": 48000,
    "codec_delay": 6500000,
    "codec_id": "A_OPUS",
    "codec_private_data": "4f707573486561640101380180bb0000000000",
    "codec_private_length": 19,
    "default_track": false,
    "enabled_track": true,
    "flag_commentary": true,
    "forced_track": false,
    "language": "eng",
    "language_ietf": "en",
    "minimum_timestamp": 0,
    "num_index_entries": 0,
    "number": 3,
    "tag_encoder": "Lavc61.19.101 libopus",
    "track_name": "Commentary",
    "uid": 2184537024976972723
   },
   "type": "audio"
  },
  {
   "codec": "SubRip/SRT",
   "id": 3,
   "properties": {
    "codec_id": "S_TEXT/UTF8",
    "codec_private_length": 0,
    "default_track": true,
    "enabled_track": true,
    "encoding": "UTF-8",
    "forced_track": true,
    "language": "eng",
    "language_ietf": "en",
    "minimum_timestamp": 500000000,
    "num_index_entries": 2,
    "number": 4,
    "text_subtitles": true,
    "track_name": "Signs",
    "uid": 17389891100597187705
   },
   "type": "subtitles"
  }
 ],
 "warnings": []
}
"""#

    static let noAudio103 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3000000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "6ee901fad920c22e31d13b5a0fc2a97e",
   "timestamp_scale": 1000000,
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "noaudio.mkv",
 "global_tags": [],
 "identification_format_version": 20,
 "track_tags": [],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "101117",
    "tag_duration": "00:00:03.000000000",
    "tag_number_of_bytes": "37919",
    "tag_number_of_frames": "72",
    "uid": 13112148195753916012
   },
   "type": "video"
  },
  {
   "codec": "SubRip/SRT",
   "id": 1,
   "properties": {
    "codec_id": "S_TEXT/UTF8",
    "codec_private_length": 0,
    "default_track": true,
    "enabled_track": true,
    "encoding": "UTF-8",
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 500000000,
    "num_index_entries": 2,
    "number": 2,
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "34",
    "tag_duration": "00:00:02.300000000",
    "tag_number_of_bytes": "10",
    "tag_number_of_frames": "2",
    "text_subtitles": true,
    "uid": 10526217425174344120
   },
   "type": "subtitles"
  }
 ],
 "warnings": []
}
"""#

    static let noAudio82 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3000000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "6ee901fad920c22e31d13b5a0fc2a97e",
   "timestamp_scale": 1000000,
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "noaudio.mkv",
 "global_tags": [],
 "identification_format_version": 19,
 "track_tags": [],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "uid": 13112148195753916012
   },
   "type": "video"
  },
  {
   "codec": "SubRip/SRT",
   "id": 1,
   "properties": {
    "codec_id": "S_TEXT/UTF8",
    "codec_private_length": 0,
    "default_track": true,
    "enabled_track": true,
    "encoding": "UTF-8",
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 500000000,
    "num_index_entries": 2,
    "number": 2,
    "text_subtitles": true,
    "uid": 10526217425174344120
   },
   "type": "subtitles"
  }
 ],
 "warnings": []
}
"""#

    static let noSubtitles103 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3042000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "4bf3a9d6cc8876bbd4fec875a06e7c3a",
   "timestamp_scale": 1000000,
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "nosubs.mkv",
 "global_tags": [
  {
   "num_entries": 1
  }
 ],
 "identification_format_version": 20,
 "track_tags": [],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "101117",
    "tag_duration": "00:00:03.000000000",
    "tag_number_of_bytes": "37919",
    "tag_number_of_frames": "72",
    "uid": 466481091845252449
   },
   "type": "video"
  },
  {
   "codec": "AAC",
   "id": 1,
   "properties": {
    "audio_channels": 1,
    "audio_sampling_frequency": 44100,
    "codec_id": "A_AAC",
    "codec_private_data": "120856e500",
    "codec_private_length": 5,
    "default_duration": 23219954,
    "default_track": true,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 0,
    "number": 2,
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "69170",
    "tag_duration": "00:00:03.042000000",
    "tag_number_of_bytes": "26302",
    "tag_number_of_frames": "131",
    "uid": 694475754797432946
   },
   "type": "audio"
  }
 ],
 "warnings": []
}
"""#

    static let noSubtitles82 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3042000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "4bf3a9d6cc8876bbd4fec875a06e7c3a",
   "timestamp_scale": 1000000,
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "nosubs.mkv",
 "global_tags": [
  {
   "num_entries": 1
  }
 ],
 "identification_format_version": 19,
 "track_tags": [],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "uid": 466481091845252449
   },
   "type": "video"
  },
  {
   "codec": "AAC",
   "id": 1,
   "properties": {
    "audio_channels": 1,
    "audio_sampling_frequency": 44100,
    "codec_id": "A_AAC",
    "codec_private_data": "120856e500",
    "codec_private_length": 5,
    "default_duration": 23219954,
    "default_track": true,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 0,
    "number": 2,
    "uid": 694475754797432946
   },
   "type": "audio"
  }
 ],
 "warnings": []
}
"""#

    static let videoOnly103 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3000000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "90395a04a0b44e3d62efa43ee081c790",
   "timestamp_scale": 1000000,
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "videoonly.mkv",
 "global_tags": [],
 "identification_format_version": 20,
 "track_tags": [],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "tag__statistics_tags": "BPS DURATION NUMBER_OF_FRAMES NUMBER_OF_BYTES",
    "tag__statistics_writing_app": "mkvmerge v103.0 ('The Darkness') 64-bit",
    "tag__statistics_writing_date_utc": "2026-11-19 05:42:45",
    "tag_bps": "101117",
    "tag_duration": "00:00:03.000000000",
    "tag_number_of_bytes": "37919",
    "tag_number_of_frames": "72",
    "uid": 11514549183013262174
   },
   "type": "video"
  }
 ],
 "warnings": []
}
"""#

    static let videoOnly82 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "date_local": "2026-11-18T22:42:45-07:00",
   "date_utc": "2026-11-19T05:42:45Z",
   "duration": 3000000000,
   "is_providing_timestamps": true,
   "muxing_application": "libebml v1.4.7 + libmatroska v1.7.2",
   "segment_uid": "90395a04a0b44e3d62efa43ee081c790",
   "timestamp_scale": 1000000,
   "writing_application": "mkvmerge v103.0 ('The Darkness') 64-bit"
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "videoonly.mkv",
 "global_tags": [],
 "identification_format_version": 19,
 "track_tags": [],
 "tracks": [
  {
   "codec": "AVC/H.264/MPEG-4p10",
   "id": 0,
   "properties": {
    "codec_id": "V_MPEG4/ISO/AVC",
    "codec_private_data": "01f4000affe1001967f4000a9196828df9f011000003000100000300300f1226a001000568ce0f1920",
    "codec_private_length": 41,
    "default_duration": 41666666,
    "default_track": true,
    "display_dimensions": "160x90",
    "display_unit": 0,
    "enabled_track": true,
    "forced_track": false,
    "language": "und",
    "language_ietf": "und",
    "minimum_timestamp": 0,
    "num_index_entries": 1,
    "number": 1,
    "packetizer": "mpeg4_p10_video",
    "pixel_dimensions": "160x90",
    "uid": 11514549183013262174
   },
   "type": "video"
  }
 ],
 "warnings": []
}
"""#

    static let empty103 = #"""
{
 "container": {
  "recognized": false,
  "supported": false
 },
 "errors": [],
 "file_name": "zero.mkv",
 "identification_format_version": 20,
 "warnings": []
}
"""#

    static let empty82 = #"""
{
 "container": {
  "recognized": false,
  "supported": false
 },
 "errors": [],
 "file_name": "zero.mkv",
 "identification_format_version": 19,
 "warnings": []
}
"""#

    static let garbage103 = #"""
{
 "container": {
  "recognized": false,
  "supported": false
 },
 "errors": [],
 "file_name": "garbage.mkv",
 "identification_format_version": 20,
 "warnings": []
}
"""#

    static let garbage82 = #"""
{
 "container": {
  "recognized": false,
  "supported": false
 },
 "errors": [],
 "file_name": "garbage.mkv",
 "identification_format_version": 19,
 "warnings": []
}
"""#

    static let truncated103 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "is_providing_timestamps": true,
   "muxing_application": "",
   "timestamp_scale": 1000000,
   "writing_application": ""
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "truncated.mkv",
 "global_tags": [],
 "identification_format_version": 20,
 "track_tags": [],
 "tracks": [],
 "warnings": []
}
"""#

    static let truncated82 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 17,
   "is_providing_timestamps": true,
   "muxing_application": "",
   "timestamp_scale": 1000000,
   "writing_application": ""
  },
  "recognized": true,
  "supported": true,
  "type": "Matroska"
 },
 "errors": [],
 "file_name": "truncated.mkv",
 "global_tags": [],
 "identification_format_version": 19,
 "track_tags": [],
 "tracks": [],
 "warnings": []
}
"""#

    static let srtNamedMKV103 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 27,
   "is_providing_timestamps": true
  },
  "recognized": true,
  "supported": true,
  "type": "SRT subtitles"
 },
 "errors": [],
 "file_name": "notmkv.mkv",
 "global_tags": [],
 "identification_format_version": 20,
 "track_tags": [],
 "tracks": [
  {
   "codec": "SubRip/SRT",
   "id": 0,
   "properties": {
    "text_subtitles": true
   },
   "type": "subtitles"
  }
 ],
 "warnings": []
}
"""#

    static let srtNamedMKV82 = #"""
{
 "attachments": [],
 "chapters": [],
 "container": {
  "properties": {
   "container_type": 27,
   "is_providing_timestamps": true
  },
  "recognized": true,
  "supported": true,
  "type": "SRT subtitles"
 },
 "errors": [],
 "file_name": "notmkv.mkv",
 "global_tags": [],
 "identification_format_version": 19,
 "track_tags": [],
 "tracks": [
  {
   "codec": "SubRip/SRT",
   "id": 0,
   "properties": {
    "text_subtitles": true
   },
   "type": "subtitles"
  }
 ],
 "warnings": []
}
"""#

    static let cannotOpen103 = #"""
{
 "errors": [
  "The file 'missing.mkv' could not be opened for reading: open file error.\n"
 ],
 "warnings": []
}
"""#

    static let cannotOpen82 = #"""
{
 "errors": [
  "The file 'missing.mkv' could not be opened for reading: open file error.\n"
 ],
 "warnings": []
}
"""#

}
