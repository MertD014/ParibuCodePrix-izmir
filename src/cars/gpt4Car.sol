// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../interfaces/Car.sol";
import "../CodePrix.sol";

contract GPT4Car is Car {
    function takeYourTurn(
        CodePrix codePrix,
        CodePrix.CarData[] calldata allCars,
        uint256 ourCarIndex
    ) external override {
        CodePrix.CarData memory ourCar = allCars[ourCarIndex];

        // Yarışın erken safhalarında daha fazla hızlanma stratejisi uygulayalım
        uint32 currentSpeed = ourCar.speed;
        uint32 currentY = ourCar.y;
        uint32 currentBalance = ourCar.balance;
        uint256 finishDistance = 1000; // CodePrix sözleşmesindeki FINISH_DISTANCE

        // Önümüzdeki arabayı bul ve pozisyonumuzu değerlendir
        bool isFirstPlace = ourCarIndex == 0;
        bool isLastPlace = ourCarIndex == allCars.length - 1;

        // Bitiş çizgisine olan mesafeyi hesapla
        uint256 distanceToFinish = finishDistance > currentY
            ? finishDistance - currentY
            : 0;

        // Mevcut pozisyonumuza ve bitiş çizgisine olan mesafemize göre en iyi kararı verelim

        // 1. Shell atma stratejisi: Önümüzdeki araba bizden daha hızlıysa ve yakınsa
        if (!isFirstPlace && allCars[ourCarIndex - 1].speed > currentSpeed) {
            uint256 shellCost = codePrix.getShellCost(1);

            // Önümüzdeki arabanın mesafesini hesapla
            uint256 distanceToCarAhead = allCars[ourCarIndex - 1].y - currentY;

            // Eğer öndeki arabanın gittiği yolu mevcut hızımızla kısa sürede kapatabileceksek kabuk atmaya gerek yok
            bool canCatchUpSoon = distanceToCarAhead <= currentSpeed * 2;

            // Eğer öndeki araba çok hızlı gidiyorsa ve kabuk atmanın bize avantaj sağlayacağını düşünüyorsak
            if (
                !canCatchUpSoon &&
                currentBalance > shellCost &&
                allCars[ourCarIndex - 1].speed > currentSpeed + 1
            ) {
                codePrix.buyShell(1);
                currentBalance -= uint32(shellCost);
            }
        }

        // 2. Hızlanma stratejisi
        // Yarışın farklı aşamalarında farklı hızlanma stratejileri uygulayalım

        // Bitiş çizgisine yaklaştıysak çok fazla hızlanmaya para harcamayalım
        bool nearFinishLine = distanceToFinish < 200;

        // Yarışın başındayız, agresif hızlanma stratejisi
        if (currentY < 300 && !nearFinishLine) {
            // En yüksek hıza ulaşmak için daha fazla hızlanma satın al
            uint256 accelerationsToReach = 3; // Hedef hız artışı
            uint256 accelerationCost = codePrix.getAccelerateCost(
                accelerationsToReach
            );

            // Bütçemize göre hızlanma miktarını ayarla
            while (
                accelerationCost > currentBalance && accelerationsToReach > 1
            ) {
                accelerationsToReach--;
                accelerationCost = codePrix.getAccelerateCost(
                    accelerationsToReach
                );
            }

            if (
                accelerationsToReach > 0 && accelerationCost <= currentBalance
            ) {
                currentBalance -= uint32(
                    codePrix.buyAcceleration(accelerationsToReach)
                );
            }
        }
        // Yarışın ortalarındayız
        else if (currentY >= 300 && currentY < 700 && !nearFinishLine) {
            // Dengeli hızlanma stratejisi
            if (
                isLastPlace ||
                (ourCarIndex > 0 &&
                    allCars[ourCarIndex - 1].speed > currentSpeed)
            ) {
                // Gerideyiz, hızlanmaya daha fazla yatırım yapalım
                uint256 accelerationsNeeded = 2;
                uint256 accelerationCost = codePrix.getAccelerateCost(
                    accelerationsNeeded
                );

                if (accelerationCost <= currentBalance) {
                    currentBalance -= uint32(
                        codePrix.buyAcceleration(accelerationsNeeded)
                    );
                } else if (codePrix.getAccelerateCost(1) <= currentBalance) {
                    currentBalance -= uint32(codePrix.buyAcceleration(1));
                }
            } else {
                // Öndeyiz veya iyi durumdayız, dengeli hızlanma
                if (codePrix.getAccelerateCost(1) <= currentBalance) {
                    currentBalance -= uint32(codePrix.buyAcceleration(1));
                }
            }
        }
        // Yarışın son kısmındayız
        else if (nearFinishLine) {
            // Bitiş çizgisine ulaşmak için gereken minimum hızı hesaplayalım
            uint256 turnsToFinish = distanceToFinish > 0
                ? (distanceToFinish + currentSpeed - 1) / currentSpeed
                : 0;

            // Eğer mevcut hızımız bizi birinci olmaya yetmiyorsa ve öndeki araba daha hızlı gidiyorsa
            if (
                !isFirstPlace && allCars[ourCarIndex - 1].speed > currentSpeed
            ) {
                uint256 accelerationsNeeded = 1;
                uint256 accelerationCost = codePrix.getAccelerateCost(
                    accelerationsNeeded
                );

                if (accelerationCost <= currentBalance) {
                    currentBalance -= uint32(
                        codePrix.buyAcceleration(accelerationsNeeded)
                    );
                }
            }
            // Eğer birinciyiz ve arkamızdaki araba bizi tehdit ediyorsa
            else if (
                isFirstPlace &&
                ourCarIndex < allCars.length - 1 &&
                allCars[ourCarIndex + 1].speed >= currentSpeed &&
                allCars[ourCarIndex + 1].y >= currentY - 100
            ) {
                uint256 accelerationsNeeded = 1;
                uint256 accelerationCost = codePrix.getAccelerateCost(
                    accelerationsNeeded
                );

                if (accelerationCost <= currentBalance) {
                    currentBalance -= uint32(
                        codePrix.buyAcceleration(accelerationsNeeded)
                    );
                }
            }
        }

        // 3. Son bir kabuk atma kontrolü daha
        // Hala paramız varsa ve birinci değilsek, öndeki arabaya kabuk atmayı deneyelim
        if (
            !isFirstPlace &&
            ourCarIndex > 0 &&
            currentBalance > codePrix.getShellCost(1)
        ) {
            CodePrix.CarData memory carAhead = allCars[ourCarIndex - 1];

            // Eğer öndeki araba hızlıysa ve bizi tehdit ediyorsa kabuk atalım
            if (carAhead.speed > currentSpeed && carAhead.speed > 1) {
                codePrix.buyShell(1);
            }
        }
    }
}
