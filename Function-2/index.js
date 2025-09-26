
const functions = require('@google-cloud/functions-framework');
const axios = require('axios');


functions.http('helloHttp', async (req, res) => {
    try {
        console.log("Webhook invoked");
        const body = req.body;
        // Get the tag
        const fulfillmentInfo = body.fulfillmentInfo || {};
        const tag = fulfillmentInfo.tag || null;
        let apiMessage = "Webhook called with unknown or no tag.";
        let sessionParams = {};

        if (tag === "callStartApi") {
            console.log("Webhook status");
            const apiUrl = "https://dev1-cct.rogers.com/dev01-config/ivr-config-ms/ivr/8335293704/call-start/params";
            const headers = {
                cdr: "112432245667775757",
                clientSystem: "IVR",
                brand: "FIDO",
                transactionId: "454545323",
                transactionDateTime: "2024-11-07T10:23:00",
                ivrSubscriptionKey: "f9422c1450c747aaaca69253a489f3c6"
            };
            const apiResponse = await axios.get(apiUrl, { headers });
            console.log("API Response:", apiResponse.data);
            const dnisParams = apiResponse.data.dnisParams || {};
            const aniParams = apiResponse.data.aniParams || {};
            const returnCode = apiResponse.data.returnCode;
            sessionParams = {
                SearchBusinessContact: dnisParams.icmSearch?.searchBusinessContact,
                HomeContact: dnisParams.icmSearch?.searchHomeContact,
                MobileContact: dnisParams.icmSearch?.searchMobileContact,
                aniConfirm: dnisParams.aniConfirm,
                aniLookup: dnisParams.aniLookup,
                dnisLang: dnisParams.language?.offerLanguageMenu,
                identifyAccount: dnisParams.identifyAccount,
                npaLanguage: aniParams.npaLanguage,
                offerlanguageMenu: dnisParams.language?.offerLanguageMenu,
                predctiveEnd: dnisParams.predictiveInd,
                validAni: aniParams.validANI,
                returnCode: returnCode
            };
        } else if (tag === "AniIdentification") {
            const apiUrl = "https://dev1-cct.rogers.com/dev01-identification/ivr-identification-ms/idc/data";
            const headers = {
                cdr: "112432245667775757",
                clientSystem: "IVR",
                brand: "FIDO",
                transactionId: "4545453232",
                transactionDateTime: "2024-11-07T10:23:00",
                ivrSubscriptionKey: "f9422c1450c747aaaca69253a489f3c6"
            };
            const params = {
                brand: "FIDO",
                searchHomeContact: "Y",
                searchMobileContact: "Y",
                searchBusinessContact: "Y",
                phoneNumber: "1010000061",
                predictiveInd: "Y"
            };
            const apiResponse = await axios.get(apiUrl, { headers, params });
            console.log("Identification API Response:", apiResponse.data);
            // Extract identifiedCustomer and AccountList
            const identifiedCustomer = apiResponse.data.identifiedCustomer;
            let accountList = [];
            if (apiResponse.data.idcData && apiResponse.data.idcData.primaryContacts) {
                apiResponse.data.idcData.primaryContacts.forEach(contact => {
                    if (contact.customers) {
                        contact.customers.forEach(customer => {
                            if (customer.accounts) {
                                customer.accounts.forEach(account => {
                                    if (account.accountNumber) {
                                        accountList.push(account.accountNumber);
                                    }
                                });
                            }
                        });
                    }
                });
            }
            sessionParams = {
                identifiedCustomer: identifiedCustomer,
                AccountList: accountList
            };
            apiMessage = "Identification API call successful";
        }
        // Only return session parameters
        const webhookResponse = {
            sessionInfo: { parameters: { apiMessage, ...sessionParams } }
        };
        console.log("Final Response:", JSON.stringify(webhookResponse));
        // Return JSON
        res.setHeader("Content-Type", "application/json");
        res.status(200).send(webhookResponse);
    } catch (err) {
        console.error("Error in webhook:", err);
        res.status(500).json({
            fulfillmentResponse: {
                messages: [
                    { text: { text: ["Webhook error occurred."] } }
                ]
            }
        });
    }
});
