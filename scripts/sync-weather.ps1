$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$directory = Join-Path $root "products\weather"
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$locations = @(
  @{ province = "江苏"; name = "南京"; latitude = 32.0603; longitude = 118.7969 },
  @{ province = "江苏"; name = "无锡"; latitude = 31.4912; longitude = 120.3119 },
  @{ province = "江苏"; name = "徐州"; latitude = 34.2044; longitude = 117.2858 },
  @{ province = "江苏"; name = "常州"; latitude = 31.8107; longitude = 119.9741 },
  @{ province = "江苏"; name = "苏州"; latitude = 31.2989; longitude = 120.5853 },
  @{ province = "江苏"; name = "南通"; latitude = 31.9802; longitude = 120.8943 },
  @{ province = "江苏"; name = "连云港"; latitude = 34.5967; longitude = 119.2216 },
  @{ province = "江苏"; name = "淮安"; latitude = 33.6104; longitude = 119.0153 },
  @{ province = "江苏"; name = "盐城"; latitude = 33.3477; longitude = 120.1633 },
  @{ province = "江苏"; name = "扬州"; latitude = 32.3942; longitude = 119.4129 },
  @{ province = "江苏"; name = "镇江"; latitude = 32.1878; longitude = 119.4250 },
  @{ province = "江苏"; name = "泰州"; latitude = 32.4555; longitude = 119.9231 },
  @{ province = "江苏"; name = "宿迁"; latitude = 33.9630; longitude = 118.2752 },
  @{ province = "安徽"; name = "合肥"; latitude = 31.8206; longitude = 117.2272 },
  @{ province = "安徽"; name = "芜湖"; latitude = 31.3525; longitude = 118.4331 },
  @{ province = "安徽"; name = "蚌埠"; latitude = 32.9163; longitude = 117.3897 },
  @{ province = "安徽"; name = "淮南"; latitude = 32.6255; longitude = 116.9999 },
  @{ province = "安徽"; name = "马鞍山"; latitude = 31.6705; longitude = 118.5068 },
  @{ province = "安徽"; name = "淮北"; latitude = 33.9558; longitude = 116.7983 },
  @{ province = "安徽"; name = "铜陵"; latitude = 30.9454; longitude = 117.8121 },
  @{ province = "安徽"; name = "安庆"; latitude = 30.5429; longitude = 117.0635 },
  @{ province = "安徽"; name = "黄山"; latitude = 29.7147; longitude = 118.3376 },
  @{ province = "安徽"; name = "滁州"; latitude = 32.3016; longitude = 118.3171 },
  @{ province = "安徽"; name = "阜阳"; latitude = 32.8901; longitude = 115.8142 },
  @{ province = "安徽"; name = "宿州"; latitude = 33.6461; longitude = 116.9642 },
  @{ province = "安徽"; name = "六安"; latitude = 31.7349; longitude = 116.5077 },
  @{ province = "安徽"; name = "亳州"; latitude = 33.8446; longitude = 115.7786 },
  @{ province = "安徽"; name = "池州"; latitude = 30.6648; longitude = 117.4916 },
  @{ province = "安徽"; name = "宣城"; latitude = 30.9407; longitude = 118.7588 }
)
Write-Host "Refreshing weather snapshots for $($locations.Count) cities..."
$responses = New-Object System.Collections.Generic.List[object]
$sourceUrls = New-Object System.Collections.Generic.List[string]
for ($offset = 0; $offset -lt $locations.Count; $offset += 10) {
  $end = [math]::Min($locations.Count - 1, $offset + 9)
  $batch = @($locations[$offset..$end])
  $latitudes = (($batch | ForEach-Object { [string]$_['latitude'] }) -join ',')
  $longitudes = (($batch | ForEach-Object { [string]$_['longitude'] }) -join ',')
  $url = "https://api.open-meteo.com/v1/forecast?latitude=$latitudes&longitude=$longitudes&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,precipitation,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max&timezone=Asia%2FShanghai&forecast_days=7"
  [void]$sourceUrls.Add($url)
  $rawResponse = Invoke-RestMethod -Uri $url -TimeoutSec 60
  $batchResponses = @($rawResponse)
  Write-Host "  batch $offset-$end returned $($batchResponses.Count) locations"
  foreach ($response in $batchResponses) { [void]$responses.Add($response) }
}
if ($responses.Count -ne $locations.Count) { throw "Open-Meteo returned $($responses.Count) locations; expected $($locations.Count)." }
$features = for ($index = 0; $index -lt $locations.Count; $index++) {
  $location = $locations[$index]
  $weather = $responses[$index]
  $forecast = for ($day = 0; $day -lt @($weather.daily.time).Count; $day++) {
    [ordered]@{
      date = $weather.daily.time[$day]
      weatherCode = $weather.daily.weather_code[$day]
      temperatureMax = $weather.daily.temperature_2m_max[$day]
      temperatureMin = $weather.daily.temperature_2m_min[$day]
      precipitation = $weather.daily.precipitation_sum[$day]
      windSpeedMax = $weather.daily.wind_speed_10m_max[$day]
    }
  }
  [ordered]@{
    type = "Feature"
    id = "$($location.province)-$($location.name)"
    properties = [ordered]@{
      province = $location.province
      name = $location.name
      observedAt = $weather.current.time
      temperature = $weather.current.temperature_2m
      apparentTemperature = $weather.current.apparent_temperature
      humidity = $weather.current.relative_humidity_2m
      weatherCode = $weather.current.weather_code
      precipitation = $weather.current.precipitation
      windSpeed = $weather.current.wind_speed_10m
      windDirection = $weather.current.wind_direction_10m
      forecast = @($forecast)
    }
    geometry = [ordered]@{ type = "Point"; coordinates = @([double]$location.longitude, [double]$location.latitude) }
  }
}
$payload = [ordered]@{
  type = "FeatureCollection"
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  source = "Open-Meteo"
  attribution = "Weather data by Open-Meteo.com (CC BY 4.0)"
  features = @($features)
}
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$target = Join-Path $directory "latest.geojson"
[IO.File]::WriteAllText($target, ($payload | ConvertTo-Json -Depth 10), $utf8NoBom)
$manifest = [ordered]@{
  schemaVersion = 1
  generatedAt = $payload.generatedAt
  sourceUrls = @($sourceUrls)
  locations = $locations.Count
  bytes = (Get-Item -LiteralPath $target).Length
  sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
  license = "CC BY 4.0"
}
[IO.File]::WriteAllText((Join-Path $directory "weather.manifest.json"), ($manifest | ConvertTo-Json -Depth 5), $utf8NoBom)
Get-Item -LiteralPath $target | Select-Object FullName, Length, LastWriteTime
