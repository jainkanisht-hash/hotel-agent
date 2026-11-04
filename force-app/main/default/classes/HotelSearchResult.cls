global without sharing class HotelSearchResult {

    @InvocableMethod(label='Get Hotel Details' description='Returns hotel details based on input ID, Name, and City')
    global static List<HotelDetailsResponse> getHotelDetails(List<HotelDetailsRequest> requests) {
        List<HotelDetailsResponse> responses = new List<HotelDetailsResponse>();

        Map<String, Hotel> catalog = getHotelCatalog();

        for (HotelDetailsRequest req : requests) {
            HotelDetailsResponse res = new HotelDetailsResponse();

            String inputId   = (req.hotelInput != null) ? req.hotelInput.hotelId : null;
            String inputName = (req.hotelInput != null) ? req.hotelInput.name    : null;
            String inputCity = (req.hotelInput != null) ? req.hotelInput.city    : null;

            Hotel match = (inputId != null) ? catalog.get(inputId.toUpperCase()) : null;

            if (match != null) {
                res.hotelInfo = match;
            } else {
                res.hotelInfo = new Hotel(
                    (inputId   != null) ? inputId   : 'HTL-000',
                    (inputName != null) ? inputName : 'Unknown Hotel',
                    (inputCity != null) ? inputCity : 'Unknown',
                    '15:00',               
                    '11:00',               
                    generatePrice(),       
                    generateRating()
                );
            }

            responses.add(res);
        }
        return responses;
    }

    private static Map<String, Hotel> getHotelCatalog() {
        Map<String, Hotel> catalog = new Map<String, Hotel>();
        catalog.put('HTL-101', new Hotel('HTL-101', 'The Grand Plaza', 'New York',  '15:00', '11:00', 320L, 4.6));
        catalog.put('HTL-202', new Hotel('HTL-202', 'Seaside Resort',  'Miami',     '16:00', '12:00', 240L, 4.3));
        catalog.put('HTL-303', new Hotel('HTL-303', 'Mountain Lodge',  'Denver',    '14:00', '10:00', 180L, 4.1));
        catalog.put('HTL-404', new Hotel('HTL-404', 'City Center Inn', 'Chicago',   '15:00', '11:00', 150L, 3.9));
        catalog.put('HTL-505', new Hotel('HTL-505', 'Palm Boutique',   'Los Angeles','15:00','11:00', 410L, 4.8));
        return catalog;
    }

    private static Long generatePrice() {
        return 80 + (Long)(Math.random() * 400);
    }

    private static Decimal generateRating() {
        return Decimal.valueOf(Math.round((3 + Math.random() * 2) * 10)) / 10;
    }

    global class HotelDetailsRequest {
        @InvocableVariable(label='Select Hotel' required=true)
        public Hotel hotelInput;
    }

    global class HotelDetailsResponse {
        @InvocableVariable(label='Hotel Details')
        public Hotel hotelInfo;
    }

    global class Hotel {
        @InvocableVariable public String hotelId;
        @InvocableVariable public String name;
        @InvocableVariable public String city;
        @InvocableVariable public String checkInTime;
        @InvocableVariable public String checkOutTime;
        @InvocableVariable public Long pricePerNight;
        @InvocableVariable public Decimal rating;

        public Hotel(String hotelId, String name, String city, String checkInTime, String checkOutTime, Long pricePerNight, Decimal rating) {
            this.hotelId = hotelId;
            this.name = name;
            this.city = city;
            this.checkInTime = checkInTime;
            this.checkOutTime = checkOutTime;
            this.pricePerNight = pricePerNight;
            this.rating = rating;
        }

        public Hotel() {

        }
    }
}