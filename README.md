## Localizador: Effortless CSV-to-Android Strings Converter

**Localizador** is a modern, cross-platform desktop application built with Flutter that streamlines the process of converting CSV translation files into Android-compatible `strings.xml` resources. Designed for localization teams, Android developers, and translators, Localizador offers an intuitive drag-and-drop interface.

<img width="1511" height="1060" alt="Preview" src="https://github.com/user-attachments/assets/14ccdeae-aa4f-4abf-8bd1-0f619e97090e" />

#### Usage Video
https://github.com/user-attachments/assets/757cb45c-9a91-486d-b4eb-d3cba423137b


### ✨ Features

- **Drag & Drop CSV Localization:** Instantly import your translation CSV files by simply dragging and dropping them into the app.
- **Automatic Android Resource Generation:** Converts each language column in your CSV header into a proper `values-<lang>` folder and `strings.xml` file, following Android’s best practices.
- **Smart Data Handling:** Only the columns defined in the CSV header are processed—extra columns in data rows are ignored, ensuring clean and accurate output.
- **Key Replacement & Merging:** Existing keys in `strings.xml` are updated with new translations, while untouched keys remain, making it safe for iterative localization.
- **Multi-Platform:** Runs natively on Linux and Windows desktops.
- **Recent Folders & Quick Access:** Remembers your last used output folders for fast, efficient workflows.
- **Safe XML Output:** Handles special characters and ensures Android-compatible XML formatting.

### 🚀 How It Works

1.  **Prepare your CSV:**
    You can create the CSV file manually or use our Google Sheets template for a more automated workflow.

    #### Option A: Using the Google Sheets Template (Recommended)
    We've created a Google Sheet with a built-in script to help you translate and export your strings into a Localizador-compatible CSV file.

    1.  **Make a copy** of the [Localizador Google Sheet](https://docs.google.com/spreadsheets/d/1sv3lz-ncYHhhy7PdkrI-2jICfrZGM9_USw5WKiK18Tk/edit?usp=sharing).
    2.  **Add your strings:**
        *   In **Column A**, starting from row 2, paste your string keys (e.g., `hello_world`, `welcome_message`).
        *   In the same column, add the English source text inside the XML tag (e.g., `<string name="hello_world">Hello World</string>`).
    3.  **Define languages:** In **Row 1**, starting from Column B, enter the language codes you want to translate to (e.g., `es`, `fr`, `de`).
    4.  **Translate:** From the main menu, go to **Translate & Export > Translate Data**. The script will automatically fill in the translations using Google Translate.
    5.  **Export:** Once ready, go to **Translate & Export > Download as CSV**. This will generate a CSV file perfectly formatted for Localizador.

    #### Option B: Creating the CSV Manually
    If you prefer to create the CSV file yourself, ensure it follows this format:
    *   The first row must be a header: `key,es,fr,...`
    *   Each subsequent row must contain the string key in the first column, followed by its corresponding translations for each language.

2.  **Drag & Drop:**
    Drop your generated CSV file into the Localizador app, or use the file picker to select it.

3.  **Select Output Folder:**
    Choose your Android project's `res` folder (or any other folder where you want the output to be saved).

4.  **Done!**
    Localizador automatically creates or updates the `values-<lang>/strings.xml` files for each language defined in your CSV header.

#### Example

**Input CSV:**
```csv
key,es,fr
hello,Hola,Bonjour
how_are_you,Cómo estás,Comment vas-tu
colors,"Rojo, amarillo, rosa","Rouge, jaune, rose"
```

**Output:**
- `res/values-es/strings.xml`
- `res/values-fr/strings.xml`

   `res/values-es/strings.xml` will contain:
   ```xml
   <?xml version='1.0' encoding='utf-8'?>
   <resources>
      <string name="hello">Hola</string>
      <string name="how_are_you">Cómo estás</string>
      <string name="colors">Rojo, amarillo, rosa</string>
   </resources>
   ```

Each file will contain the appropriate XML-formatted strings for its language.

### 🔥 Why Localizador?

- **Save hours** on manual copy-pasting and error-prone resource editing.
- **Perfect for teams** working with translators and multiple languages.
- **Streamline your workflow** using the provided Google Sheets template.
- **Open source** and easy to extend.

### 🧪 Testing

Localizador includes comprehensive automated tests to ensure reliability:

- **Unit Tests:** The core CSV processing logic is thoroughly tested with various scenarios including edge cases and error conditions.
- **Test Coverage:** Tests cover CSV validation, XML generation, file handling, special characters, and error scenarios.

To run the tests:
```bash
flutter test
```
