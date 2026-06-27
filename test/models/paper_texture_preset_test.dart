import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  group('PaperTexturePreset', () {
    group('all preset constants exist', () {
      test('PaperTexturePreset.smooth exists', () {
        expect(PaperTexturePreset.smooth, isA<PaperTexturePreset>());
      });

      test('PaperTexturePreset.standard exists', () {
        expect(PaperTexturePreset.standard, isA<PaperTexturePreset>());
      });

      test('PaperTexturePreset.textured exists', () {
        expect(PaperTexturePreset.textured, isA<PaperTexturePreset>());
      });

      test('PaperTexturePreset.kraft exists', () {
        expect(PaperTexturePreset.kraft, isA<PaperTexturePreset>());
      });

      test('values list contains all four presets', () {
        expect(PaperTexturePreset.values.length, 4);
        expect(
          PaperTexturePreset.values,
          containsAll([
            PaperTexturePreset.smooth,
            PaperTexturePreset.standard,
            PaperTexturePreset.textured,
            PaperTexturePreset.kraft,
          ]),
        );
      });

      test('enum indices are in declaration order', () {
        expect(PaperTexturePreset.smooth.index, 0);
        expect(PaperTexturePreset.standard.index, 1);
        expect(PaperTexturePreset.textured.index, 2);
        expect(PaperTexturePreset.kraft.index, 3);
      });

      test('enum names match declaration names', () {
        expect(PaperTexturePreset.smooth.name, 'smooth');
        expect(PaperTexturePreset.standard.name, 'standard');
        expect(PaperTexturePreset.textured.name, 'textured');
        expect(PaperTexturePreset.kraft.name, 'kraft');
      });
    });

    group('factory produces correct configs', () {
      test('fromPreset(smooth) returns low friction/stiffness/roughness config',
          () {
        final config = PaperTextureConfig.fromPreset(PaperTexturePreset.smooth);

        expect(config.friction, 0.1);
        expect(config.stiffness, 0.2);
        expect(config.roughness, 0.1);
        expect(config.baseSharpness, 0.8);
      });

      test('fromPreset(standard) returns balanced default config', () {
        final config =
            PaperTextureConfig.fromPreset(PaperTexturePreset.standard);

        expect(config.friction, 0.2);
        expect(config.stiffness, 0.4);
        expect(config.roughness, 0.3);
        expect(config.baseSharpness, 0.5);
      });

      test('fromPreset(textured) returns medium intensity config', () {
        final config =
            PaperTextureConfig.fromPreset(PaperTexturePreset.textured);

        expect(config.friction, 0.5);
        expect(config.stiffness, 0.6);
        expect(config.roughness, 0.8);
        expect(config.baseSharpness, 0.6);
      });

      test('fromPreset(kraft) returns high intensity config', () {
        final config = PaperTextureConfig.fromPreset(PaperTexturePreset.kraft);

        expect(config.friction, 0.7);
        expect(config.stiffness, 0.9);
        expect(config.roughness, 1.2);
        expect(config.baseSharpness, 0.4);
      });

      test('each preset returns distinct PaperTextureConfig instances', () {
        final smooth = PaperTextureConfig.fromPreset(PaperTexturePreset.smooth);
        final standard =
            PaperTextureConfig.fromPreset(PaperTexturePreset.standard);
        final textured =
            PaperTextureConfig.fromPreset(PaperTexturePreset.textured);
        final kraft = PaperTextureConfig.fromPreset(PaperTexturePreset.kraft);

        // Each preset should differ in at least one parameter
        expect(smooth.friction, lessThan(standard.friction));
        expect(standard.friction, lessThan(textured.friction));
        expect(textured.friction, lessThan(kraft.friction));
      });
    });

    group('custom PaperTextureConfig creation', () {
      test('custom config can be created with all parameters', () {
        const customConfig = PaperTextureConfig(
          friction: 0.3,
          stiffness: 0.5,
          roughness: 0.6,
          baseSharpness: 0.7,
        );

        expect(customConfig.friction, 0.3);
        expect(customConfig.stiffness, 0.5);
        expect(customConfig.roughness, 0.6);
        expect(customConfig.baseSharpness, 0.7);
      });

      test('custom config uses default baseSharpness when not specified', () {
        const customConfig = PaperTextureConfig(
          friction: 0.5,
          stiffness: 0.5,
          roughness: 0.5,
        );

        expect(customConfig.baseSharpness, 0.5);
      });

      test('custom config can have extreme values', () {
        const extremeConfig = PaperTextureConfig(
          friction: 1,
          stiffness: 1,
          roughness: 2,
          baseSharpness: 0,
        );

        expect(extremeConfig.friction, 1.0);
        expect(extremeConfig.stiffness, 1.0);
        expect(extremeConfig.roughness, 2.0);
        expect(extremeConfig.baseSharpness, 0.0);
      });

      test('custom config can have minimum values', () {
        const minConfig = PaperTextureConfig(
          friction: 0,
          stiffness: 0,
          roughness: 0,
          baseSharpness: 0,
        );

        expect(minConfig.friction, 0.0);
        expect(minConfig.stiffness, 0.0);
        expect(minConfig.roughness, 0.0);
        expect(minConfig.baseSharpness, 0.0);
      });
    });

    group('PaperTextureConfig equality', () {
      test('identical configs are equal', () {
        const config1 = PaperTextureConfig(
          friction: 0.3,
          stiffness: 0.5,
          roughness: 0.6,
        );
        const config2 = PaperTextureConfig(
          friction: 0.3,
          stiffness: 0.5,
          roughness: 0.6,
        );

        expect(config1, equals(config2));
      });

      test('different configs are not equal', () {
        const config1 = PaperTextureConfig(
          friction: 0.3,
          stiffness: 0.5,
          roughness: 0.6,
        );
        const config2 = PaperTextureConfig(
          friction: 0.4,
          stiffness: 0.5,
          roughness: 0.6,
        );

        expect(config1, isNot(equals(config2)));
      });
    });
  });
}
