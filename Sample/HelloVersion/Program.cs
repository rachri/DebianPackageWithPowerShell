using System;
using System.Reflection;

namespace HelloVersion
{
    class Program
    {
        static void Main(string[] args)
        {
            Version v = Assembly.GetExecutingAssembly().GetName().Version;
            Console.WriteLine($"Hello Version {v}");
        }
    }
}
