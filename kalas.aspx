<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Configuration" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json; charset=utf-8";
    Response.Charset = "utf-8";
    
    StringBuilder log = new StringBuilder();
    
    try
    {
        log.AppendLine("=== get_kalas.aspx Started ===");
        log.AppendLine("Time: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        
        // ==========================================
        // خواندن تنظیمات از web.config - C# قدیمی
        // ==========================================
        string dbServer = ConfigurationManager.AppSettings["DbServer"];
        string dbName = ConfigurationManager.AppSettings["DbName"];
        string dbUser = ConfigurationManager.AppSettings["DbUser"];
        string dbPassword = ConfigurationManager.AppSettings["DbPassword"];
        string customerId = ConfigurationManager.AppSettings["CustomerId"];
        
        // بررسی null با ?: (C# قدیمی)
        if (string.IsNullOrEmpty(dbServer)) dbServer = "localhost";
        if (string.IsNullOrEmpty(dbName)) dbName = "database";
        if (string.IsNullOrEmpty(dbUser)) dbUser = "user";
        if (string.IsNullOrEmpty(dbPassword)) dbPassword = "";
        if (string.IsNullOrEmpty(customerId)) customerId = "default";
        
        log.AppendLine("Config loaded - Server: " + dbServer + ", Database: " + dbName);
        
        // ==========================================
        // ساخت Connection String - C# قدیمی
        // ==========================================
        string connectionString = "Server=" + dbServer + 
                                  ";Database=" + dbName + 
                                  ";User Id=" + dbUser + 
                                  ";Password=" + dbPassword + ";";
        
        log.AppendLine("Connection string built");
        
        // ==========================================
        // اتصال به دیتابیس
        // ==========================================
        var items = new System.Collections.Generic.List<System.Collections.Generic.Dictionary<string, string>>();
        
        using (SqlConnection conn = new SqlConnection(connectionString))
        {
            conn.Open();
            log.AppendLine("Database connected");
            
            // کوئری - همه فیلدهای جدول kala
            string query = @"
                SELECT 
                    ISNULL(codek, '') AS codek,
                    ISNULL(namek, N'بدون نام') AS namek,
                    ISNULL(price_sale1, 0) AS price_sale1,
                    ISNULL(price_buy1, 0) AS price_buy1,
                    ISNULL(tedad, 0) AS tedad,
                    ISNULL(unit, N'عدد') AS unit,
                    ISNULL(description, N'') AS description,
                    ISNULL(category_id, N'') AS category_id,
                    ISNULL(active, 1) AS active
                FROM dbo.kala 
                WHERE active = 1
                ORDER BY codek";
            
            using (SqlCommand cmd = new SqlCommand(query, conn))
            {
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var item = new System.Collections.Generic.Dictionary<string, string>();
                        
                        item["codek"] = reader["codek"].ToString();
                        item["namek"] = reader["namek"].ToString();
                        item["price_sale1"] = reader["price_sale1"].ToString();
                        item["price_buy1"] = reader["price_buy1"].ToString();
                        item["tedad"] = reader["tedad"].ToString();
                        item["unit"] = reader["unit"].ToString();
                        item["description"] = reader["description"].ToString();
                        item["category_id"] = reader["category_id"].ToString();
                        item["active"] = reader["active"].ToString();
                        
                        items.Add(item);
                    }
                }
            }
        }
        
        log.AppendLine("Items loaded: " + items.Count);
        
        // ==========================================
        // ساخت JSON پاسخ
        // ==========================================
        var result = new
        {
            status = "ok",
            count = items.Count,
            items = items,
            log = log.ToString()
        };
        
        var serializer = new JavaScriptSerializer();
        serializer.MaxJsonLength = int.MaxValue;
        Response.Write(serializer.Serialize(result));
    }
    catch (SqlException sqlEx)
    {
        log.AppendLine("SQL ERROR: " + sqlEx.Message);
        
        var error = new
        {
            status = "error",
            message = "خطای SQL: " + sqlEx.Message,
            items = new object[] { },
            log = log.ToString()
        };
        
        Response.StatusCode = 500;
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(error));
    }
    catch (Exception ex)
    {
        log.AppendLine("ERROR: " + ex.Message);
        log.AppendLine("Stack: " + ex.StackTrace);
        
        var error = new
        {
            status = "error",
            message = "خطا: " + ex.Message,
            items = new object[] { },
            log = log.ToString()
        };
        
        Response.StatusCode = 500;
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(error));
    }
}
</script>
