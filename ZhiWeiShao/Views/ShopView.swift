import SwiftUI

struct ShopView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.navPath) private var path

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t("选购"))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Palette.secondary)
                        Text(store.t("商城"))
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Button {
                        path?.wrappedValue.append(AppRoute.bag)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bag")
                                .font(.system(size: 18, weight: .regular))
                            if store.bagCount() > 0 {
                                Text("\(store.bagCount())")
                                    .font(.system(size: 13, weight: .regular))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("open-bag")
                    .accessibilityLabel(store.bagCount() > 0 ? "\(store.t("购物袋")) \(store.bagCount())" : store.t("购物袋"))
                }
                Text(store.t("轻食，以及可以换上的餐具。"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14, alignment: .top),
                        GridItem(.flexible(), spacing: 14, alignment: .top)
                    ],
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(Catalog.products) { product in
                        ProductTile(product: product, title: store.t(product.name)) {
                            path?.wrappedValue.append(AppRoute.product(product.id))
                        }
                    }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .pageBackground()
    }
}

private struct ProductTile: View {
    var product: Product
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ProductPhoto(name: product.imageName, height: 108, radius: 16)
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                PriceText(price: product.price, size: 15)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("product-\(product.id)")
        .accessibilityLabel("\(title)，\(product.priceText)")
    }
}

struct ProductPhoto: View {
    var name: String
    var height: CGFloat
    var radius: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 0.5)
            }
            .accessibilityIdentifier("product-photo-\(name)")
    }
}

struct ProductDetailView: View {
    var productId: String
    @Environment(AppStore.self) private var store

    var body: some View {
        if let product = Catalog.product(productId) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ProductPhoto(name: product.imageName, height: 300, radius: 28)
                    Text(store.t(product.eyebrow))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                        .padding(.top, 28)
                    Text(store.t(product.name))
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 4)
                    PriceText(price: product.price, size: 20)
                        .padding(.top, 12)
                    Text(store.t(product.story))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(3)
                        .padding(.top, 22)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.t("包含"))
                        .font(.system(size: 17, weight: .regular))
                        .padding(.top, 36)
                    VStack(spacing: 0) {
                        ForEach(Array(product.includes.enumerated()), id: \.offset) { index, line in
                            HStack {
                                Text(store.t(line))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            if index < product.includes.count - 1 { Hairline() }
                        }
                    }
                    .padding(.top, 4)
                    QuietNote(text: store.t("价格已包含在标价里。没有倒计时，也没有预先勾选的项目。"))
                        .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: store.t("加入购物袋"), identifier: "add-to-bag") {
                    store.addToBag(productId: product.id)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        } else {
            Text(store.t("没有找到这件商品"))
                .font(.system(size: 17, weight: .regular))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BagView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.bag.isEmpty {
                    Text(store.t("购物袋是空的"))
                        .font(.system(size: 22, weight: .regular))
                        .padding(.top, 24)
                    QuietNote(text: store.t("选好之后可以放进来。购买还没有开放。"))
                        .padding(.top, 8)
                } else {
                    ForEach(store.bag) { line in
                        if let product = Catalog.product(line.productId) {
                            HStack(alignment: .center, spacing: 16) {
                                Image(product.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 72, height: 72)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.t(product.name))
                                        .font(.system(size: 17, weight: .regular))
                                    Text(store.t("数量 \(line.quantity)"))
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(Palette.secondary)
                                }
                                Spacer()
                                PriceText(price: product.price * line.quantity, size: 16)
                            }
                            .padding(.vertical, 14)
                            Hairline()
                        }
                    }
                    QuietNote(text: store.t("购买还没有开放。这里只是暂时放着，不会自动结算。"))
                        .padding(.top, 20)
                    TextAction(title: store.t("继续浏览")) { dismiss() }
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
