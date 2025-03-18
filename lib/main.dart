import 'dart:io';
import 'dart:convert'; // To work with JSON data
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as devtools;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recipe Recognizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? filePath;
  String label = '';
  bool isLoading = false;
  List<Map<String, dynamic>> recipeData = []; // List to store recipe data
  List<Map<String, dynamic>> recognitionResults = []; // Store recognition results

  // Load the model and labels
  Future<void> _tfLiteInit() async {
    await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labeljs.txt",
      numThreads: 4,
      isAsset: true,
      useGpuDelegate: false,
    );

    // Load the recipe data from the JSON file
    String jsonData = await DefaultAssetBundle.of(context).loadString('assets/recipes.json');
    List<dynamic> jsonResponse = json.decode(jsonData);
    setState(() {
      recipeData = jsonResponse.map((item) => item as Map<String, dynamic>).toList();
    });

    // Log recipe data for debugging
    devtools.log("Recipe Data: $recipeData");
  }

  // Pick image from gallery or camera
  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    setState(() {
      filePath = File(image.path);
    });
  }

  // Classify the selected image
  Future<void> classifyImage() async {
    if (filePath == null) return;

    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    var recognitions = await Tflite.runModelOnImage(
      path: filePath!.path,
      imageMean: 0.846,
      imageStd: 1,
      numResults: 25,
      threshold: 0.2,
      asynch: true,
    );

    setState(() {
      isLoading = false;
    });

    // Log all model results for debugging
    devtools.log("Model Results: $recognitions");

    if (recognitions == null || recognitions.isEmpty) {
      devtools.log("No valid recognitions");
      return;
    }

    // Sort results by confidence in descending order
    recognitions.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));

    // Take the top 5 predictions
    List<Map<String, dynamic>> top5Results = recognitions.take(5).map((result) {
      return {
        'label': result['label'],
        'confidence': result['confidence'],
      };
    }).toList();

    // Log top 5 results
    devtools.log("Top 5 Results: $top5Results");

    // Map predictions to recipe information
    List<Map<String, dynamic>> resultWithRecipes = [];
    for (var recognition in recognitions) {
      String label = recognition['label'].trim().toLowerCase();

      // Find all matching recipes
      var matchingRecipes = recipeData.where(
              (recipe) => recipe['class_name'].trim().toLowerCase() == label
      ).toList();

      if (matchingRecipes.isNotEmpty) {
        for (var recipe in matchingRecipes) {
          resultWithRecipes.add({
            'label': recognition['label'],
            'confidence': recognition['confidence'],
            'image_url': recipe['image_url'],
            'recipe_name': recipe['Name'],
            'ingredients': recipe['Ingredients'],
            'method': recipe['Method'],
          });
        }
      }
    }

    // Store recognition results
    setState(() {
      recognitionResults = resultWithRecipes;
    });

    // Navigate to the results page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsPage(results: resultWithRecipes),
      ),
    );
  }

  // Clear the selected image
  void clearImage() {
    setState(() {
      filePath = null;
    });
  }

  // Dispose resources
  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  // Initialize the app
  @override
  void initState() {
    super.initState();
    _tfLiteInit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recipe Recognizer"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            // Tablet or desktop layout
            return _buildWideLayout();
          } else {
            // Mobile layout
            return _buildNormalLayout();
          }
        },
      ),
    );
  }

  Widget _buildNormalLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Welcome to Chef AI",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () => pickImage(ImageSource.gallery),
                  child: buildCard("Upload Image", "Select from gallery", Icons.upload_file),
                ),
                GestureDetector(
                  onTap: () => pickImage(ImageSource.camera),
                  child: buildCard("Use Camera", "Take a picture", Icons.camera_alt),
                ),
              ],
            ),
            const SizedBox(height: 20),
            buildImageCard(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: filePath == null ? null : classifyImage,
                  child: isLoading ? const CircularProgressIndicator() : const Text("Confirm"),
                ),
                ElevatedButton(
                  onPressed: clearImage,
                  child: const Text("Cancel"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Welcome to Chef AI",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: () => pickImage(ImageSource.gallery),
                        child: buildCard("Upload Image", "Select from gallery", Icons.upload_file),
                      ),
                      GestureDetector(
                        onTap: () => pickImage(ImageSource.camera),
                        child: buildCard("Use Camera", "Take a picture", Icons.camera_alt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  buildImageCard(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: filePath == null ? null : classifyImage,
                        child: isLoading ? const CircularProgressIndicator() : const Text("Confirm"),
                      ),
                      ElevatedButton(
                        onPressed: clearImage,
                        child: const Text("Cancel"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(), // Add additional content for wide layout
            ),
          ],
        ),
      ),
    );
  }

  // Build card for image source options
  Widget buildCard(String title, String description, IconData icon) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        height: MediaQuery.of(context).size.width * 0.4,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: MediaQuery.of(context).size.width * 0.1),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // Build image display card
  Widget buildImageCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.3,
        child: filePath == null
            ? Icon(Icons.upload_file, size: MediaQuery.of(context).size.width * 0.2, color: Colors.grey)
            : Image.file(filePath!, fit: BoxFit.cover),
      ),
    );
  }
}

// Results Page
class ResultsPage extends StatelessWidget {
  final List<Map<String, dynamic>> results;

  const ResultsPage({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recognition Results"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: results.map((result) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailScreen(recipe: result),
                  ),
                );
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  result['image_url'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                result['label'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "${result['recipe_name']}\nConfidence: ${(result['confidence'] * 100).toStringAsFixed(2)}%",
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Recipe Details Page
class RecipeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Image (35% of screen height with bottom border radius)
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              image: DecorationImage(
                image: NetworkImage(recipe['image_url']),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                // Back Button with Background Color
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5), // Background color
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context); // Go back to the results page
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Recipe Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label (Class Name)
                  Text(
                    recipe['label'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Recipe Name
                  Text(
                    recipe['recipe_name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Ingredients
                  const Text(
                    "Ingredients",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recipe['ingredients'].map<Widget>((ingredient) {
                    return Text(
                      "• $ingredient",
                      style: const TextStyle(fontSize: 16),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  // Method
                  const Text(
                    "Method",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recipe['method'].map<Widget>((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        step,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}