import collections
import os

def RepresentsInt(s):
    try:
        int(s)
        return True
    except ValueError:
        return False

class Coords:
    def __init__(self, lat, lng):
        self.lat = lat
        self.lng = lng

class Arrival:
    def __init__(self, route, direction, stopId, stopRank, passingTime, trip, lat, lng):
        self.route = route
        self.direction = direction
        self.stopId = int(stopId)
        self.stopRank = int(stopRank)
        self.passingTime = int(passingTime)
        self.trip = int(trip)
        self.location = Coords(lat,lng)

class Stop:
    def __init__(self, stopId, stopDescription, lat, lng):
        self.id = stopId
        self.description = stopDescription
        self.location = Coords(lat,lng)
        self.routes = {}

class Route:
    def __init__(self, route, direction):
        self.name = route
        self.direction = direction
        self.morning = []
        self.midday = []
        self.afternoon = []
        self.unservedmorning = 120
        self.unservedafternoon = 120

        if RepresentsInt(route[0]):
            self.transbay = 'no'
            self.nolocals = 'no'
        elif route in ['FS', 'L', 'LA', 'NX', 'NX1', 'NX2', 'NX3', 'U', 'W']:
            self.transbay = 'yes'
            self.nolocals = 'yes'
        else:
            self.transbay = 'yes'
            self.nolocals = 'no'

class Departure:
    def __init__(self, time, tripNum, terminus):
        self.time = time
        self.trip = tripNum
        self.terminus = terminus

stops = {}
trips = collections.deque()
termini = {}
minLat = 100.0
maxLat = 0.0

f = open('hastusExport_latest.txt','r')
header = f.readline().strip().split('\t')
dayIndex = header.index('DayOfWeek')
routeIndex = header.index('Route')
directionIndex = header.index('Direction')
stopIdIndex = header.index('StopID')
stopDescIndex = header.index('StopDescription')
stopRankIndex = header.index('StopRank')
passingTimeIndex = header.index('TripPassingTime')
longitudeIndex = header.index('Longitude')
latitudeIndex = header.index('Latitude')
tripIndex = header.index('Trip')

for line in f:
    record = line.split('\t')
    if record == [""]:
        continue
    day = record[dayIndex]
    route = record[routeIndex]
    direction = record[directionIndex]
    stopId = record[stopIdIndex]
    stopDescription = record[stopDescIndex].replace("&","&amp;")
    stopRank = record[stopRankIndex]
    passingTime = record[passingTimeIndex]
    longitude = record[longitudeIndex]
    latitude = record[latitudeIndex].rstrip()
    tripPattern = record[tripIndex]

    if ( day == "Weekday" and RepresentsInt(stopId)
         and not(len(route) > 1 and route[-1] == 'C')
         and not(len(route) == 3 and route[0] == '3')
         and not(len(route) == 3 and route[0] == '6')
         and not(len(route) == 3 and route[0] == '8')
         and route != "BSD"
         and route != "BSN"):
        stopId=int(stopId)
        if passingTime[-1] == 'p':
            passingTimeMinutes = 720
        elif passingTime[-1] == 'b':
            passingTimeMinutes = 720
        else:
            passingTimeMinutes = 0
        passingTimeMinutes += int(passingTime[-3:-1])
        if len(passingTime) == 5:
            passingTimeMinutes += int(passingTime[0:2]) * 60
        else:
            passingTimeMinutes += int(passingTime[0:1]) * 60

        passingTime = passingTimeMinutes
        trips.append( Arrival(route,direction,stopId,stopRank,passingTime,tripPattern,latitude,longitude) )
        if stopId not in stops:
            stops[stopId] = Stop(stopId,stopDescription,latitude,longitude)
            if float(latitude) < minLat:
                minLat = float(latitude)
            elif float(latitude) > maxLat:
                maxLat = float(latitude)

print(len(trips)) ## displays on the console that the file has been parsed
print(len(stops))

for trip in trips:
    if trip.trip in termini:
        if trip.stopRank > termini[trip.trip]['stopRank']:
            termini[trip.trip]['terminus'] = trip.location
            termini[trip.trip]['stopRank'] = trip.stopRank
    elif (trip.direction[0:3].upper() == "NOR"
            or trip.direction[0:3].upper() == "SOU"
            or trip.direction[0:3].upper() == "EAS"
            or trip.direction[0:3].upper() == "WES"):
        termini[trip.trip] = { 'terminus': trip.location, 'stopRank': trip.stopRank }
    else:
        termini[trip.trip] = { 'terminus': Coords(0,0), 'stopRank': 999 }

for trip in trips:

    routeDir = trip.route + "_" + trip.direction
    terminus = termini[trip.trip]['terminus']

    if routeDir not in stops[trip.stopId].routes:
        stops[trip.stopId].routes[routeDir] = Route(trip.route,trip.direction)

    if 359 < trip.passingTime < 540:
        stops[trip.stopId].routes[routeDir].morning.append(Departure(trip.passingTime,trip.trip,terminus))
    elif 659 < trip.passingTime < 720:
        stops[trip.stopId].routes[routeDir].midday.append(Departure(trip.passingTime,trip.trip,terminus))
    elif 959 < trip.passingTime < 1080:
        stops[trip.stopId].routes[routeDir].afternoon.append(Departure(trip.passingTime,trip.trip,terminus))

for stop in stops:
    for route in stops[stop].routes:

        morningTrips = []
        afternoonTrips = []

        for departure in stops[stop].routes[route].morning:
            morningTrips.append(departure.time)
        for departure in stops[stop].routes[route].afternoon:
            afternoonTrips.append(departure.time)

        if len(morningTrips) > 0:
            morningTrips.sort()
            stops[stop].routes[route].unservedmorning = morningTrips[0] - 360
            for i in range(1,len(morningTrips)):
                if (morningTrips[i] - morningTrips[i-1]) > stops[stop].routes[route].unservedmorning:
                    stops[stop].routes[route].unservedmorning = morningTrips[i] - morningTrips[i-1]
            if (540 - morningTrips[len(morningTrips)-1]) > stops[stop].routes[route].unservedmorning:
                stops[stop].routes[route].unservedmorning = 540 - morningTrips[len(morningTrips)-1]
            if stops[stop].routes[route].unservedmorning > 120:
                stops[stop].routes[route].unservedmorning = 120

        if len(afternoonTrips) > 0:
            afternoonTrips.sort()
            stops[stop].routes[route].unservedafternoon = afternoonTrips[0] - 960
            for i in range(1,len(afternoonTrips)):
                if (afternoonTrips[i] - afternoonTrips[i-1]) > stops[stop].routes[route].unservedafternoon:
                    stops[stop].routes[route].unservedafternoon = afternoonTrips[i] - afternoonTrips[i-1]
            if (1080 - afternoonTrips[len(afternoonTrips)-1]) > stops[stop].routes[route].unservedafternoon:
                stops[stop].routes[route].unservedafternoon = 1080 - afternoonTrips[len(afternoonTrips)-1]
            if stops[stop].routes[route].unservedafternoon > 120:
                stops[stop].routes[route].unservedafternoon = 120

ltsout = {}
if not os.path.exists('ltsData/'):
    os.mkdir('ltsData/')
for i in range(int(minLat*100),int(maxLat*100)+1):
    strOutFileName = 'ltsData/ltsData{0}.xml'.format(str(i))
    ltsout[i] = open(strOutFileName,'w')
    ltsout[i].write('<?xml version="1.0" encoding="utf-8" ?>\n<transitstops minlat="{minLat}" maxlat="{maxLat}">'.format(minLat=str(float(i-1)/100),maxLat=str(float(i+1)/100)));

for stop in stops:
    strRoutes = "<routes>"
    for route in stops[stop].routes:
        morningTrips = ""
        middayTrips = ""
        afternoonTrips = ""

        for departure in stops[stop].routes[route].morning:
            morningTrips += """<trip num="{tripNum}" endlat="{lat}" endlng="{lng}">{time}</trip>""".format(tripNum=departure.trip,lat=departure.terminus.lat,lng=departure.terminus.lng,time=departure.time)

        for departure in stops[stop].routes[route].midday:
            middayTrips += """<trip num="{tripNum}" endlat="{lat}" endlng="{lng}">{time}</trip>""".format(tripNum=departure.trip,lat=departure.terminus.lat,lng=departure.terminus.lng,time=departure.time)

        for departure in stops[stop].routes[route].afternoon:
            afternoonTrips += """<trip num="{tripNum}" endlat="{lat}" endlng="{lng}">{time}</trip>""".format(tripNum=departure.trip,lat=departure.terminus.lat,lng=departure.terminus.lng,time=departure.time)

        routeString = """<route name="{route}" direction="{direction}" tbay="{transbay}" nolocals="{nolocals}" unservedam="{unservedmorning}" unservedpm="{unservedafternoon}"><amtrips>{morningTrips}</amtrips><noontrips>{middayTrips}</noontrips><pmtrips>{afternoonTrips}</pmtrips></route>""".format( route = stops[stop].routes[route].name,
                                                                                     direction = stops[stop].routes[route].direction,
                                                                                     transbay = stops[stop].routes[route].transbay,
                                                                                     nolocals = stops[stop].routes[route].nolocals,
                                                                                     unservedmorning = stops[stop].routes[route].unservedmorning,
                                                                                     unservedafternoon = stops[stop].routes[route].unservedafternoon,
                                                                                     morningTrips = morningTrips,
                                                                                     middayTrips = middayTrips,
                                                                                     afternoonTrips = afternoonTrips)
        strRoutes += routeString

    strRoutes += "</routes>"
    stopString = """<stop id="{id}" desc="{desc}" lat="{lat}" lng="{lng}">{rteString}</stop>""".format(id = stops[stop].id,
                                                            desc = stops[stop].description,
                                                            lat = stops[stop].location.lat,
                                                            lng = stops[stop].location.lng,
                                                            rteString = strRoutes)

    writeToFileNum = int(float(stops[stop].location.lat) * 100)
    ltsout[writeToFileNum].write(stopString)
    if (writeToFileNum - 1) in ltsout:
        ltsout[writeToFileNum - 1].write(stopString)
    if (writeToFileNum + 1) in ltsout:
        ltsout[writeToFileNum + 1].write(stopString)

f.close()

for file in ltsout:
    ltsout[file].write("\n</transitstops>")
    ltsout[file].close()

hmout = open('ltsData/hmData.js','w')
hmoutput ='data:['
highestCommuterScore = 0
for stop in stops:
    commuterScore = 0

    for route in stops[stop].routes:
        commuterScore += len(stops[stop].routes[route].morning) + len(stops[stop].routes[route].afternoon)
        if stops[stop].routes[route].transbay:
            commuterScore += 3
        if stops[stop].routes[route].nolocals:
            commuterScore -= 1

    if commuterScore > highestCommuterScore:
        highestCommuterScore = commuterScore
    hmoutput += "{{lat:{lat},lng:{lng},count:{count}}},".format(lat = stops[stop].location.lat, lng = stops[stop].location.lng, count = commuterScore)
hmoutput += '{lat:37.8052810,lng:-122.2685230,count:1}]};'
hmout.write('var heatmapData={max:' + str(highestCommuterScore) + ',' + hmoutput)
hmout.close()

indexFile = open('ltsData/index.html','w')
indexFile.write('<!doctype html>\n<html>\n<head>\n\t<title>Looking for something?</title>\n\t<meta name="robots" content="noindex, nofollow" />\n</head>\n<body>\n\t<!-- Nothing to see here -->\n</body>\n</html>')
indexFile.close()