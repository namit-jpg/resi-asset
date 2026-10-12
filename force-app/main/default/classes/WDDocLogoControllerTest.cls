@IsTest
private class WDDocLogoControllerTest {
    @IsTest
    static void returnsDataUriForLogoResource() {
        String uri = new WDDocLogoController().logoDataUri;
        Boolean hasResource = ![SELECT Id FROM StaticResource WHERE Name = :WDDocLogoController.LOGO_RESOURCE].isEmpty();
        if (hasResource) {
            System.assert(uri.startsWith('data:'), 'Expected a data URI for the logo');
            System.assert(uri.contains(';base64,'), 'Expected base64 encoding');
        } else {
            System.assertEquals('', uri, 'Expected empty string when the resource is missing');
        }
    }
}
