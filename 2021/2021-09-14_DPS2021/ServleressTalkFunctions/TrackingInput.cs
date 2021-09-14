using System;
using System.IO;
using System.Threading.Tasks;
using System.Collections.Generic;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using Newtonsoft.Json;

namespace ServleressTalkFunctions
{
    public static class TrackingInput
    {
        [FunctionName("TrackingInput")]
        public static async Task<IActionResult>
        Run([HttpTrigger(AuthorizationLevel.Anonymous,"get",Route = null)] HttpRequest req,
            [Blob("rawdata"),StorageAccount("MyStorageAccount")] CloudBlobContainer blobContainer,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            string sessionId = req.Query["session_id"];
            var ReceivedDT = DateTime.UtcNow;
            if (string.IsNullOrEmpty(sessionId))
            {
              log.LogError("There is no session id set in the query parameters");
              throw new ArgumentException("Session id not set.");
            }

            // create the container if it does not exist
            await blobContainer.CreateIfNotExistsAsync();

            // if not exists, create the folders 
            CloudBlobDirectory folderYear = blobContainer.GetDirectoryReference(ReceivedDT.Year.ToString());
            CloudBlobDirectory folderMonth = folderYear.GetDirectoryReference(ReceivedDT.Month.ToString());
            CloudBlobDirectory folderDay = folderMonth.GetDirectoryReference(ReceivedDT.Day.ToString());

            IDictionary<string, string> data = req.GetQueryParameterDictionary();
            
            string filename = $"tracking_{sessionId}.json";
            
            // try to get the blob to append to, if this fails, create the blob. 
            // this assumes that there are multiple tracking points sent for the same session id
            var blob = folderDay.GetAppendBlobReference(filename);
            if (!blob.ExistsAsync().Result) blob.CreateOrReplaceAsync().Wait();

            await blob
                .AppendTextAsync($"{JsonConvert.SerializeObject(data)}");

            return new OkObjectResult($"Message appended to blob for session id {sessionId}");
        }
    }
}
