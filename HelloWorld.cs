using System;

namespace HelloWorldApp
{
    class Program
    {
        static void Main(string[] args)
        {
            // Clear the console for a clean display
            Console.Clear();

            // Set a fun background color
            Console.BackgroundColor = ConsoleColor.Black;
            
            // Create a rainbow effect for "Hello, World!"
            string[] colors = { "Red", "Yellow", "Green", "Cyan", "Blue", "Magenta" };
            string message = "Hello, Wonderful World! 🌎";
            
            // Print a decorative border
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("★═══════════════════════════════★");
            
            // Print the welcome message with current time
            Console.ForegroundColor = ConsoleColor.White;
            Console.WriteLine($"\nWelcome, {Environment.UserName}!");
            Console.WriteLine($"It's {DateTime.UtcNow:F} (UTC)\n");

            // Print the main message with color changes
            foreach (char c in message)
            {
                Console.ForegroundColor = (ConsoleColor)((int)ConsoleColor.Red + new Random().Next(0, colors.Length));
                Console.Write(c);
                System.Threading.Thread.Sleep(100); // Add a small delay for effect
            }
            
            // Add some fun ASCII art
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n\n    *  *  *");
            Console.WriteLine("  *        *");
            Console.WriteLine("*  Keep    *");
            Console.WriteLine("*  Coding! *");
            Console.WriteLine("  *      *");
            Console.WriteLine("    * *");
            
            // Reset colors and add bottom border
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("\n★═══════════════════════════════★");
            
            // Reset console colors
            Console.ResetColor();
            
            // Wait for user input before closing
            Console.WriteLine("\nPress any key to exit...");
            Console.ReadKey();
        }
    }
}
